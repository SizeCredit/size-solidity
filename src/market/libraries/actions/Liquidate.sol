// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "@src/market/libraries/Math.sol";

import {PERCENT} from "@src/market/libraries/Math.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/market/libraries/LoanLibrary.sol";

import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

import {State} from "@src/market/SizeStorage.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

struct LiquidateParams {
    // The debt position ID to liquidate
    uint256 debtPositionId;
    // The minimum profit in collateral tokens expected by the liquidator
    uint256 minimumCollateralProfit;
    // The deadline for the transaction
    uint256 deadline;
}

/// @title Liquidate
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for liquidating a debt position
library Liquidate {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    /// @notice Validates the input parameters for liquidating a debt position
    /// @param state The state
    function validateLiquidate(State storage state, LiquidateParams calldata params) external view {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate msg.sender
        // N/A

        // validate debtPositionId
        if (!state.isDebtPositionLiquidatable(params.debtPositionId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.debtPositionId,
                state.collateralRatio(debtPosition.borrower),
                uint8(state.getLoanStatus(params.debtPositionId))
            );
        }

        // validate minimumCollateralProfit
        // N/A

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }
    }

    /// @notice Validates the minimum profit in collateral tokens expected by the liquidator
    /// @param params The input parameters for liquidating a debt position
    /// @param liquidatorProfitCollateralToken The profit in collateral tokens expected by the liquidator
    function validateMinimumCollateralProfit(
        State storage,
        LiquidateParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        if (liquidatorProfitCollateralToken < params.minimumCollateralProfit) {
            revert Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT(
                liquidatorProfitCollateralToken, params.minimumCollateralProfit
            );
        }
    }

    /// @notice Executes the liquidation of a debt position
    /// @param state The state
    /// @param params The input parameters for liquidating a debt position
    /// @return liquidatorProfitCollateralToken The profit in collateral tokens expected by the liquidator
    function executeLiquidate(State storage state, LiquidateParams calldata params)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        LoanStatus loanStatus = state.getLoanStatus(params.debtPositionId);
        uint256 collateralRatio = state.collateralRatio(debtPosition.borrower);

        emit Events.Liquidate(
            msg.sender,
            params.debtPositionId,
            params.minimumCollateralProfit,
            params.deadline,
            collateralRatio,
            uint8(loanStatus)
        );

        // if the loan is both underwater and overdue, the protocol fee related to underwater liquidations takes precedence
        uint256 collateralProtocolPercent = state.isUserUnderwater(debtPosition.borrower)
            ? state.feeConfig.collateralProtocolPercent
            : state.feeConfig.overdueCollateralProtocolPercent;

        uint256 assignedCollateral = state.getDebtPositionAssignedCollateral(debtPosition);
        uint256 debtInCollateralToken = state.debtTokenAmountToCollateralTokenAmount(debtPosition.futureValue);
        uint256 protocolProfitCollateralToken = 0;

        // profitable liquidation
        if (assignedCollateral > debtInCollateralToken) {
            uint256 liquidatorReward = Math.min(
                assignedCollateral - debtInCollateralToken,
                Math.mulDivUp(debtInCollateralToken, state.feeConfig.liquidationRewardPercent, PERCENT)
            );
            liquidatorProfitCollateralToken = debtInCollateralToken + liquidatorReward;

            // the protocol earns a portion of the collateral remainder
            uint256 collateralRemainder = assignedCollateral - liquidatorProfitCollateralToken;

            // cap the collateral remainder to FV * (1 - crLiquidation)
            //   otherwise, the split for non-underwater overdue loans could be too much
            uint256 collateralRemainderCap =
                Math.mulDivDown(debtInCollateralToken, state.riskConfig.crLiquidation - PERCENT, PERCENT);

            collateralRemainder = Math.min(collateralRemainder, collateralRemainderCap);

            protocolProfitCollateralToken = Math.mulDivDown(collateralRemainder, collateralProtocolPercent, PERCENT);
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state.data.transferBorrowToken(msg.sender, address(this), debtPosition.futureValue);
        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.data.collateralToken.transferFrom(
            debtPosition.borrower, state.feeConfig.feeRecipient, protocolProfitCollateralToken
        );

        state.repayDebt(params.debtPositionId, debtPosition.futureValue);
    }
}
