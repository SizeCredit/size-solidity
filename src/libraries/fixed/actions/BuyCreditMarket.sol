// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BuyCreditMarketParams {
    address borrower;
    uint256 creditPositionId;
    uint256 dueDate;
    uint256 amount;
    uint256 deadline;
    uint256 minAPR;
    bool exactAmountIn;
}

library BuyCreditMarket {
    using OfferLibrary for BorrowOffer;
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using VariablePoolLibrary for State;
    using RiskLibrary for State;

    function validateBuyCreditMarket(State storage state, BuyCreditMarketParams calldata params) external view {
        if (params.borrower != address(0)) {
            BorrowOffer memory borrowOffer = state.data.users[params.borrower].borrowOffer;
            if (borrowOffer.isNull()) {
                revert Errors.INVALID_BORROW_OFFER(params.borrower);
            }
            if (params.dueDate < block.timestamp + state.riskConfig.minimumMaturity) {
                revert Errors.PAST_DUE_DATE(params.dueDate);
            }
            if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
                revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
            }
        }

        if (params.creditPositionId != 0) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
                revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                    params.creditPositionId,
                    state.getLoanStatus(params.creditPositionId),
                    state.collateralRatio(debtPosition.borrower)
                );
            }
            if (creditPosition.credit == 0) {
                revert Errors.CREDIT_POSITION_ALREADY_CLAIMED(params.creditPositionId);
            }
            User storage user = state.data.users[creditPosition.lender];
            BorrowOffer storage borrowOffer = user.borrowOffer;
            if (borrowOffer.isNull()) {
                revert Errors.NULL_OFFER();
            }
            if (user.allCreditPositionsForSaleDisabled || !creditPosition.forSale) {
                revert Errors.CREDIT_NOT_FOR_SALE(params.creditPositionId);
            }
        }

        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        uint256 apr = (params.borrower != address(0))
            ? state.data.users[params.borrower].borrowOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate)
            : state.data.users[state.getCreditPosition(params.creditPositionId).lender].borrowOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, state.getDebtPositionByCreditPositionId(params.creditPositionId).dueDate);
        if (apr < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(apr, params.minAPR);
        }
    }

    function executeBuyCreditMarket(State storage state, BuyCreditMarketParams calldata params)
        external
        returns (uint256 amountIn)
    {
        uint256 ratePerMaturity = getRatePerMaturity(state, params);
        (uint256 amountIn, uint256 amountOut, uint256 fees) = calculateAmounts(state, params, ratePerMaturity);

        if (params.borrower != address(0)) {
            handleLending(state, params, amountOut, fees);
        } else if (params.creditPositionId != 0) {
            handleCreditBuying(state, params, amountOut, fees);
        }

        finalizeTransaction(state, msg.sender, params, amountIn, fees);
        return amountIn;
    }

    function getRatePerMaturity(State storage state, BuyCreditMarketParams calldata params) internal view returns (uint256) {
        if (params.borrower != address(0)) {
            return state.data.users[params.borrower].borrowOffer.getRatePerMaturityByDueDate(
                state.oracle.variablePoolBorrowRateFeed, params.dueDate
            );
        } else {
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            return state.data.users[state.getCreditPosition(params.creditPositionId).lender].borrowOffer.getRatePerMaturityByDueDate(
                state.oracle.variablePoolBorrowRateFeed, debtPosition.dueDate
            );
        }
    }

    function calculateAmounts(State storage state, BuyCreditMarketParams calldata params, uint256 ratePerMaturity)
        internal
        returns (uint256 amountIn, uint256 amountOut, uint256 fees)
    {
        if (params.exactAmountIn) {
            amountIn = params.amount;
            (amountOut, fees) = state.getCreditAmountOut({
                amountIn: amountIn,
                credit: params.borrower != address(0) ? Math.mulDivDown(amountIn, PERCENT + ratePerMaturity, PERCENT) : state.getCreditPosition(params.creditPositionId).credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.borrower != address(0) ? params.dueDate : state.getDebtPositionByCreditPositionId(params.creditPositionId).dueDate
            });
        } else {
            amountOut = params.amount;
            (amountIn, fees) = state.getCashAmountIn({
                amountOut: amountOut,
                credit: params.borrower != address(0) ? amountOut : state.getCreditPosition(params.creditPositionId).credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.borrower != address(0) ? params.dueDate : state.getDebtPositionByCreditPositionId(params.creditPositionId).dueDate
            });
        }
    }

    function handleLending(State storage state, BuyCreditMarketParams calldata params, uint256 amountOut, uint256 fees) internal {
        DebtPosition memory debtPosition = state.createDebtAndCreditPositions({
            lender: msg.sender,
            borrower: params.borrower,
            faceValue: amountOut,
            dueDate: params.dueDate
        });
        state.data.debtToken.mint(params.borrower, debtPosition.getTotalDebt());
        emit Events.LendAsMarketOrder(params.borrower, params.dueDate, amountOut, params.exactAmountIn);
    }

    function handleCreditBuying(State storage state, BuyCreditMarketParams calldata params, uint256 amountOut, uint256 fees) internal {
        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionId,
            lender: msg.sender,
            credit: amountOut
        });
        emit Events.BuyMarketCredit(params.creditPositionId, params.amount, params.exactAmountIn);
    }

    function finalizeTransaction(State storage state, address sender, BuyCreditMarketParams calldata params, uint256 amountIn, uint256 fees) internal {
        state.transferBorrowAToken(sender, getRecipient(state, params), amountIn - fees);
        state.transferBorrowAToken(sender, state.feeConfig.feeRecipient, fees);
    }

    function getRecipient(State storage state, BuyCreditMarketParams calldata params) internal view returns (address) {
        if (params.borrower != address(0)) {
            return params.borrower;
        } else {
            return state.getCreditPosition(params.creditPositionId).lender;
        }
    }
}