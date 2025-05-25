// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/market/libraries/YieldCurveLibrary.sol";

import {State} from "@src/market/SizeStorage.sol";

import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";

struct SellCreditMarketParams {
    // The lender
    address lender;
    // The credit position ID to sell
    // If RESERVED_ID, a new credit position will be created
    uint256 creditPositionId;
    // The amount of credit to sell
    uint256 amount;
    // The tenor of the loan
    // If creditPositionId is not RESERVED_ID, this value is ignored and the tenor of the existing loan is used
    uint256 tenor;
    // The deadline for the transaction
    uint256 deadline;
    // The maximum APR for the loan
    uint256 maxAPR;
    // Whether amount means credit or cash
    bool exactAmountIn;
    // The collection Id (introduced in v1.8)
    // If collectionId is RESERVED_ID, selects the user-defined yield curve
    uint256 collectionId;
    // The rate provider (introduced in v1.8)
    // If collectionId is RESERVED_ID, selects the user-defined yield curve
    address rateProvider;
}

struct SellCreditMarketOnBehalfOfParams {
    // The parameters for selling credit as a market order
    SellCreditMarketParams params;
    // The account to receive the debt
    address onBehalfOf;
    // The account to receive the cash
    address recipient;
}

/// @title SellCreditMarket
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for selling credit (borrowing) as a market order
library SellCreditMarket {
    using OfferLibrary for LimitOrder;
    using OfferLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;

    struct SwapDataSellCreditMarket {
        CreditPosition creditPosition;
        uint256 creditAmountIn;
        uint256 cashAmountOut;
        uint256 swapFee;
        uint256 fragmentationFee;
        uint256 tenor;
    }

    /// @notice Validates the input parameters for selling credit as a market order
    /// @param state The state
    /// @param externalParams The input parameters for selling credit as a market order
    function validateSellCreditMarket(State storage state, SellCreditMarketOnBehalfOfParams calldata externalParams)
        external
        view
    {
        SellCreditMarketParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;
        address recipient = externalParams.recipient;

        uint256 tenor;

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.SELL_CREDIT_MARKET)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.SELL_CREDIT_MARKET));
        }

        // validate recipient
        if (recipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate lender
        if (params.lender == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate creditPositionId
        if (params.creditPositionId == RESERVED_ID) {
            tenor = params.tenor;

            // validate tenor
            if (tenor < state.riskConfig.minTenor || tenor > state.riskConfig.maxTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minTenor, state.riskConfig.maxTenor);
            }
        } else {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (onBehalfOf != creditPosition.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(onBehalfOf, creditPosition.lender);
            }
            if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
                revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                    params.creditPositionId,
                    uint8(state.getLoanStatus(params.creditPositionId)),
                    state.collateralRatio(debtPosition.borrower)
                );
            }
            tenor = debtPosition.dueDate - block.timestamp; // positive since the credit position is transferrable, so the loan must be ACTIVE
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate tenor
        // N/A

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate maxAPR
        uint256 loanAPR = state.getLoanOfferAPR(params.lender, params.collectionId, params.rateProvider, tenor);
        if (loanAPR > params.maxAPR) {
            revert Errors.APR_GREATER_THAN_MAX_APR(loanAPR, params.maxAPR);
        }

        // validate exactAmountIn
        // N/A

        // validate inverted curve
        if (!state.isLoanAPRGreaterThanBorrowOfferAPRs(params.lender, loanAPR, tenor)) {
            revert Errors.INVERTED_CURVES(params.lender, tenor);
        }

        // validate collectionId
        // validate rateProvider
        // these are validated in `CollectionsManager`
    }

    /// @notice Returns the swap data for selling credit as a market order
    /// @param state The state
    /// @param params The input parameters for selling credit as a market order
    /// @return swapData The swap data for selling credit as a market order
    function getSwapData(State storage state, SellCreditMarketParams memory params)
        public
        view
        returns (SwapDataSellCreditMarket memory swapData)
    {
        if (params.creditPositionId == RESERVED_ID) {
            swapData.tenor = params.tenor;
        } else {
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            swapData.creditPosition = state.getCreditPosition(params.creditPositionId);

            swapData.tenor = debtPosition.dueDate - block.timestamp;
        }

        uint256 ratePerTenor =
            state.getLoanOfferRatePerTenor(params.lender, params.collectionId, params.rateProvider, swapData.tenor);

        if (params.exactAmountIn) {
            swapData.creditAmountIn = params.amount;

            (swapData.cashAmountOut, swapData.swapFee, swapData.fragmentationFee) = state.getCashAmountOut({
                creditAmountIn: swapData.creditAmountIn,
                maxCredit: params.creditPositionId == RESERVED_ID ? swapData.creditAmountIn : swapData.creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: swapData.tenor
            });
        } else {
            swapData.cashAmountOut = params.amount;

            (swapData.creditAmountIn, swapData.swapFee, swapData.fragmentationFee) = state.getCreditAmountIn({
                cashAmountOut: swapData.cashAmountOut,
                maxCashAmountOut: params.creditPositionId == RESERVED_ID
                    ? swapData.cashAmountOut
                    : Math.mulDivDown(
                        swapData.creditPosition.credit,
                        PERCENT - state.getSwapFeePercent(swapData.tenor),
                        PERCENT + ratePerTenor
                    ),
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? Math.mulDivUp(
                        swapData.cashAmountOut, PERCENT + ratePerTenor, PERCENT - state.getSwapFeePercent(swapData.tenor)
                    )
                    : swapData.creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: swapData.tenor
            });
        }
    }

    /// @notice Executes the selling of credit as a market order
    /// @param state The state
    /// @param externalParams The input parameters for selling credit as a market order
    function executeSellCreditMarket(State storage state, SellCreditMarketOnBehalfOfParams calldata externalParams)
        external
    {
        SellCreditMarketParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;
        address recipient = externalParams.recipient;

        emit Events.SellCreditMarket(
            msg.sender,
            onBehalfOf,
            params.lender,
            recipient,
            params.creditPositionId,
            params.amount,
            params.tenor,
            params.deadline,
            params.maxAPR,
            params.exactAmountIn,
            params.collectionId,
            params.rateProvider
        );

        SwapDataSellCreditMarket memory swapData = getSwapData(state, params);

        if (params.creditPositionId == RESERVED_ID) {
            // slither-disable-next-line unused-return
            state.createDebtAndCreditPositions({
                lender: onBehalfOf,
                borrower: onBehalfOf,
                futureValue: swapData.creditAmountIn,
                dueDate: block.timestamp + swapData.tenor
            });
        }

        uint256 exitCreditPositionId =
            params.creditPositionId == RESERVED_ID ? state.data.nextCreditPositionId - 1 : params.creditPositionId;

        state.createCreditPosition({
            exitCreditPositionId: exitCreditPositionId,
            lender: params.lender,
            credit: swapData.creditAmountIn,
            forSale: true
        });
        state.data.borrowTokenVault.transferFrom(params.lender, recipient, swapData.cashAmountOut);
        state.data.borrowTokenVault.transferFrom(
            params.lender, state.feeConfig.feeRecipient, swapData.swapFee + swapData.fragmentationFee
        );

        emit Events.SwapData(
            exitCreditPositionId,
            onBehalfOf,
            params.lender,
            swapData.creditAmountIn,
            swapData.cashAmountOut + swapData.swapFee + swapData.fragmentationFee,
            swapData.cashAmountOut,
            swapData.swapFee,
            swapData.fragmentationFee,
            swapData.tenor
        );
    }
}
