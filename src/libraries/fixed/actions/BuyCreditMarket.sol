// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

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
        bool lending = params.borrower != address(0);
        bool buying = params.creditPositionId != RESERVED_ID;

        if (buying && lending || !buying && !lending) {
            revert Errors.NOT_SUPPORTED();
        }

        if (lending) {
            BorrowOffer memory borrowOffer = state.data.users[params.borrower].borrowOffer;
            if (borrowOffer.isNull()) {
                revert Errors.INVALID_BORROW_OFFER(params.borrower);
            }
            if (params.dueDate < block.timestamp + state.riskConfig.minimumMaturity) {
                revert Errors.PAST_DUE_DATE(params.dueDate);
            }
            if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
                revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(
                    params.amount, state.riskConfig.minimumCreditBorrowAToken
                );
            }
        }

        if (buying) {
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

        uint256 apr = lending
            ? state.data.users[params.borrower].borrowOffer.getAPRByDueDate(
                state.oracle.variablePoolBorrowRateFeed, params.dueDate
            )
            : state.data.users[state.getCreditPosition(params.creditPositionId).lender].borrowOffer.getAPRByDueDate(
                state.oracle.variablePoolBorrowRateFeed,
                state.getDebtPositionByCreditPositionId(params.creditPositionId).dueDate
            );
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
            handleLending(state, params, amountIn, amountOut, fees);
        } else if (params.creditPositionId != 0) {
            handleCreditBuying(state, params, amountIn, amountOut, fees);
        }

        return amountIn;
    }

    function getRatePerMaturity(State storage state, BuyCreditMarketParams calldata params)
        internal
        view
        returns (uint256)
    {
        if (params.borrower != address(0)) {
            return state.data.users[params.borrower].borrowOffer.getRatePerMaturityByDueDate(
                state.oracle.variablePoolBorrowRateFeed, params.dueDate
            );
        } else {
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            return state.data.users[state.getCreditPosition(params.creditPositionId).lender]
                .borrowOffer
                .getRatePerMaturityByDueDate(state.oracle.variablePoolBorrowRateFeed, debtPosition.dueDate);
        }
    }

    function calculateAmounts(State storage state, BuyCreditMarketParams calldata params, uint256 ratePerMaturity)
        internal
        view
        returns (uint256 cashAmountIn, uint256 creditAmountOut, uint256 fees)
    {
        if (params.exactAmountIn) {
            cashAmountIn = params.amount;
            (creditAmountOut, fees) = state.getCreditAmountOut({
                cashAmountIn: cashAmountIn,
                maxCredit: params.borrower != address(0)
                    ? Math.mulDivDown(cashAmountIn, PERCENT + ratePerMaturity, PERCENT)
                    : state.getCreditPosition(params.creditPositionId).credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.borrower != address(0)
                    ? params.dueDate
                    : state.getDebtPositionByCreditPositionId(params.creditPositionId).dueDate
            });
        } else {
            creditAmountOut = params.amount;
            (cashAmountIn, fees) = state.getCashAmountIn({
                creditAmountOut: creditAmountOut,
                maxCredit: params.borrower != address(0) ? creditAmountOut : state.getCreditPosition(params.creditPositionId).credit,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.borrower != address(0)
                    ? params.dueDate
                    : state.getDebtPositionByCreditPositionId(params.creditPositionId).dueDate
            });
        }
    }

    function handleLending(
        State storage state,
        BuyCreditMarketParams calldata params,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fees
    ) internal {
        emit Events.LendAsMarketOrder(params.borrower, params.dueDate, amountOut, params.exactAmountIn);

        DebtPosition memory debtPosition = state.createDebtAndCreditPositions({
            lender: msg.sender,
            borrower: params.borrower,
            faceValue: amountOut,
            dueDate: params.dueDate
        });
        state.data.debtToken.mint(params.borrower, debtPosition.getTotalDebt());
        state.transferBorrowAToken(msg.sender, params.borrower, amountIn - fees);
        state.transferBorrowAToken(msg.sender, state.feeConfig.feeRecipient, fees);
    }

    function handleCreditBuying(
        State storage state,
        BuyCreditMarketParams calldata params,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fees
    ) internal {
        emit Events.BuyMarketCredit(params.creditPositionId, params.amount, params.exactAmountIn);

        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionId,
            lender: msg.sender,
            credit: amountOut
        });
        address lender = state.getCreditPosition(params.creditPositionId).lender;
        state.transferBorrowAToken(msg.sender, lender, amountIn - fees);
        state.transferBorrowAToken(msg.sender, state.feeConfig.feeRecipient, fees);
    }
}
