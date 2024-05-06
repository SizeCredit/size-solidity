// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {PERCENT} from "@src/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

import {Math} from "@src/libraries/Math.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowAsMarketOrderParams {
    address lender;
    uint256 amount;
    uint256 dueDate;
    uint256 deadline;
    uint256 maxAPR;
    bool exactAmountIn;
    uint256[] receivableCreditPositionIds;
}

library BorrowAsMarketOrder {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;
    using VariablePoolLibrary for State;
    using AccountingLibrary for State;

    function validateBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external view {
        User memory lenderUser = state.data.users[params.lender];
        LoanOffer memory loanOffer = lenderUser.loanOffer;

        // validate msg.sender
        // N/A

        // validate params.lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate params.amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }

        // validate params.dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
        if (params.dueDate > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(params.dueDate, loanOffer.maxDueDate);
        }

        // validate params.deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate params.maxAPR
        uint256 apr = loanOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate);
        if (apr > params.maxAPR) {
            revert Errors.APR_GREATER_THAN_MAX_APR(apr, params.maxAPR);
        }

        // validate params.exactAmountIn
        // N/A

        // validate params.receivableCreditPositionIds
        for (uint256 i = 0; i < params.receivableCreditPositionIds.length; ++i) {
            uint256 creditPositionId = params.receivableCreditPositionIds[i];

            CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(creditPositionId);

            if (msg.sender != creditPosition.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(msg.sender, creditPosition.lender);
            }
            if (params.dueDate < debtPosition.dueDate) {
                revert Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE(params.dueDate, debtPosition.dueDate);
            }
        }
    }

    function executeBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external {
        emit Events.BorrowAsMarketOrder(
            params.lender, params.amount, params.dueDate, params.exactAmountIn, params.receivableCreditPositionIds
        );

        params.amount = _borrowFromCredit(state, params);
        _borrowGeneratingDebt(state, params);
    }

    /// @notice Borrow with receivable credit positions, an internal state-modifying function.
    /// @dev The `amount` is initialized to `amountOutLeft`, which is decreased as more and more CreditPositions are created
    function _borrowFromCredit(State storage state, BorrowAsMarketOrderParams memory params)
        internal
        returns (uint256 amountOutLeft)
    {
        //  amountIn: Amount of future cashflow to exit
        //  amountOut: Amount of cash to borrow at present time

        User storage lenderUser = state.data.users[params.lender];

        LoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 ratePerMaturity =
            loanOffer.getRatePerMaturityByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate);

        amountOutLeft =
            params.exactAmountIn ? Math.mulDivDown(params.amount, PERCENT, PERCENT + ratePerMaturity) : params.amount;

        for (uint256 i = 0; i < params.receivableCreditPositionIds.length; ++i) {
            uint256 creditPositionId = params.receivableCreditPositionIds[i];
            CreditPosition storage creditPosition = state.getCreditPosition(creditPositionId);

            uint256 deltaAmountIn = Math.mulDivUp(amountOutLeft, PERCENT + ratePerMaturity, PERCENT);
            uint256 deltaAmountOut = amountOutLeft;
            if (deltaAmountIn > creditPosition.credit) {
                deltaAmountIn = creditPosition.credit;
                deltaAmountOut = Math.mulDivDown(creditPosition.credit, PERCENT, PERCENT + ratePerMaturity);
            }

            // the lender doesn't have enought credit to exit
            if (deltaAmountIn < state.riskConfig.minimumCreditBorrowAToken) {
                continue;
            }
            // full amount borrowed
            if (deltaAmountOut == 0) {
                break;
            }

            state.createCreditPosition({
                exitCreditPositionId: creditPositionId,
                lender: params.lender,
                credit: deltaAmountIn
            });
            state.transferBorrowAToken(params.lender, msg.sender, deltaAmountOut);
            state.transferBorrowAToken(msg.sender, state.feeConfig.feeRecipient, state.feeConfig.earlyLenderExitFee);
            amountOutLeft -= deltaAmountOut;
        }
    }

    /// @notice Borrow with generating debt
    /// @dev Cover the remaining amount by generating debt, which is subject to liquidation
    function _borrowGeneratingDebt(State storage state, BorrowAsMarketOrderParams memory params) internal {
        if (params.amount == 0) {
            return;
        }

        User storage lenderUser = state.data.users[params.lender];

        LoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 ratePerMaturity =
            loanOffer.getRatePerMaturityByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate);
        uint256 issuanceValue = params.amount;
        uint256 faceValue = Math.mulDivUp(issuanceValue, PERCENT + ratePerMaturity, PERCENT);

        DebtPosition memory debtPosition = state.createDebtAndCreditPositions({
            lender: params.lender,
            borrower: msg.sender,
            issuanceValue: issuanceValue,
            faceValue: faceValue,
            dueDate: params.dueDate
        });

        state.data.debtToken.mint(msg.sender, debtPosition.getTotalDebt());
        state.transferBorrowAToken(params.lender, msg.sender, issuanceValue);
    }
}
