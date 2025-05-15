// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "@src/market/libraries/Math.sol";

import {PERCENT} from "@src/market/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/market/libraries/LoanLibrary.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/market/libraries/YieldCurveLibrary.sol";

import {State} from "@src/market/SizeStorage.sol";

import {Liquidate, LiquidateParams} from "@src/market/libraries/actions/Liquidate.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

struct LiquidateWithReplacementParams {
    // The debt position ID to liquidate
    uint256 debtPositionId;
    // The borrower
    address borrower;
    // The minimum profit in collateral tokens expected by the liquidator
    uint256 minimumCollateralProfit;
    // The deadline for the transaction
    uint256 deadline;
    // The minimum APR for the loan
    uint256 minAPR;
}

struct LiquidateWithReplacementWithCollectionParams {
    // The parameters for liquidating a debt position with a replacement borrower
    LiquidateWithReplacementParams params;
    // The collection Id (introduced in v1.8)
    // If collectionId is RESERVED_ID, selects the user-defined yield curve
    uint256 collectionId;
    // The rate provider (introduced in v1.8)
    // If collectionId is RESERVED_ID, selects the user-defined yield curve
    address rateProvider;
}

/// @title LiquidateWithReplacement
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for liquidating a debt position with a replacement borrower
library LiquidateWithReplacement {
    using LoanLibrary for CreditPosition;
    using OfferLibrary for LimitOrder;
    using OfferLibrary for State;

    using LoanLibrary for State;
    using Liquidate for State;
    using LoanLibrary for DebtPosition;

    /// @notice Validates the input parameters for liquidating a debt position with a replacement borrower
    /// @param state The state
    /// @param withCollectionParams The input parameters for liquidating a debt position with a replacement borrower
    function validateLiquidateWithReplacement(
        State storage state,
        LiquidateWithReplacementWithCollectionParams calldata withCollectionParams
    ) external view {
        LiquidateWithReplacementParams memory params = withCollectionParams.params;
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate liquidate
        state.validateLiquidate(
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit,
                deadline: params.deadline
            })
        );

        // validate borrower
        if (params.borrower == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) != LoanStatus.ACTIVE) {
            revert Errors.LOAN_NOT_ACTIVE(params.debtPositionId);
        }
        uint256 tenor = debtPosition.dueDate - block.timestamp;
        if (tenor < state.riskConfig.minTenor || tenor > state.riskConfig.maxTenor) {
            revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }

        // validate minAPR
        uint256 borrowAPR = state.getUserDefinedBorrowOfferAPR(params.borrower, tenor);
        if (borrowAPR < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(borrowAPR, params.minAPR);
        }

        // validate exactAmountIn
        // N/A

        // validate inverted curve
        if (!state.isBorrowAPRLowerThanLoanOfferAPRs(params.borrower, borrowAPR, tenor)) {
            revert Errors.INVERTED_CURVES(params.borrower, tenor);
        }

        // validate collectionId
        // validate rateProvider
        // these are validated in `CollectionsManager`
    }

    /// @notice Validates the minimum profit in collateral tokens expected by the liquidator
    /// @param state The state
    /// @param params The input parameters for liquidating a debt position with a replacement borrower
    /// @param liquidatorProfitCollateralToken The profit in collateral tokens expected by the liquidator
    function validateMinimumCollateralProfit(
        State storage state,
        LiquidateWithReplacementParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        Liquidate.validateMinimumCollateralProfit(
            state,
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit,
                deadline: params.deadline
            }),
            liquidatorProfitCollateralToken
        );
    }

    /// @notice Executes the liquidation of a debt position with a replacement borrower
    /// @param state The state
    /// @param withCollectionParams The input parameters for liquidating a debt position with a replacement borrower
    /// @return liquidatorProfitCollateralToken The profit in collateral tokens expected by the liquidator
    /// @return liquidatorProfitBorrowToken The profit in borrow tokens expected by the liquidator
    function executeLiquidateWithReplacement(
        State storage state,
        LiquidateWithReplacementWithCollectionParams calldata withCollectionParams
    ) external returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken) {
        LiquidateWithReplacementParams memory params = withCollectionParams.params;
        emit Events.LiquidateWithReplacement(
            msg.sender,
            params.debtPositionId,
            params.borrower,
            params.minimumCollateralProfit,
            params.deadline,
            params.minAPR,
            withCollectionParams.collectionId,
            withCollectionParams.rateProvider
        );

        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        DebtPosition memory debtPositionCopy = debtPosition;
        uint256 tenor = debtPositionCopy.dueDate - block.timestamp;

        liquidatorProfitCollateralToken = state.executeLiquidate(
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit,
                deadline: params.deadline
            })
        );

        uint256 ratePerTenor = state.getBorrowOfferRatePerTenor(
            params.borrower, withCollectionParams.collectionId, withCollectionParams.rateProvider, tenor
        );
        uint256 issuanceValue = Math.mulDivDown(debtPositionCopy.futureValue, PERCENT, PERCENT + ratePerTenor);
        liquidatorProfitBorrowToken = debtPositionCopy.futureValue - issuanceValue;

        debtPosition.borrower = params.borrower;
        debtPosition.futureValue = debtPositionCopy.futureValue;
        debtPosition.liquidityIndexAtRepayment = 0;

        emit Events.UpdateDebtPosition(
            params.debtPositionId,
            debtPosition.borrower,
            debtPosition.futureValue,
            debtPosition.liquidityIndexAtRepayment
        );

        state.data.debtToken.mint(params.borrower, debtPosition.futureValue);
        state.data.borrowTokenVault.transferFrom(address(this), params.borrower, issuanceValue);
        state.data.borrowTokenVault.transferFrom(
            address(this), state.feeConfig.feeRecipient, liquidatorProfitBorrowToken
        );
    }
}
