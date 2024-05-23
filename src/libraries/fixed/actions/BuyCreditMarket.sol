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
        BorrowOffer memory borrowOffer = state.data.users[params.borrower].borrowOffer;

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }

        // validate creditPositionId
        if (params.creditPositionId != RESERVED_ID) {
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
            if (user.allCreditPositionsForSaleDisabled || !creditPosition.forSale) {
                revert Errors.CREDIT_NOT_FOR_SALE(params.creditPositionId);
            }
            if (params.dueDate != debtPosition.dueDate) {
                revert Errors.DUE_DATE_NOT_COMPATIBLE(params.dueDate, debtPosition.dueDate);
            }
            if (params.borrower != creditPosition.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(params.borrower, creditPosition.lender);
            }
        }

        // validate dueDate
        if (params.dueDate < block.timestamp + state.riskConfig.minimumMaturity) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }

        // validate amount
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minAPR
        uint256 apr = borrowOffer.getAPRByDueDate(state.oracle.variablePoolBorrowRateFeed, params.dueDate);
        if (apr < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(apr, params.minAPR);
        }

        // validate exactAmountIn
        // N/A
    }

    function executeBuyCreditMarket(State storage state, BuyCreditMarketParams memory params)
        external
        returns (uint256 cashAmountIn)
    {
        emit Events.BuyCreditMarket(params.borrower, params.creditPositionId, params.amount, params.exactAmountIn);

        uint256 ratePerMaturity = state.data.users[params.borrower].borrowOffer.getRatePerMaturityByDueDate(
            state.oracle.variablePoolBorrowRateFeed, params.dueDate
        );

        uint256 creditAmountOut;
        uint256 fees;

        if (params.exactAmountIn) {
            cashAmountIn = params.amount;
            (creditAmountOut, fees) = state.getCreditAmountOut({
                cashAmountIn: cashAmountIn,
                maxCredit: Math.mulDivDown(cashAmountIn, PERCENT + ratePerMaturity, PERCENT),
                ratePerMaturity: ratePerMaturity,
                dueDate: params.dueDate
            });
        } else {
            creditAmountOut = params.amount;
            (cashAmountIn, fees) = state.getCashAmountIn({
                creditAmountOut: creditAmountOut,
                maxCredit: creditAmountOut,
                ratePerMaturity: ratePerMaturity,
                dueDate: params.dueDate
            });
        }

        if (params.creditPositionId == RESERVED_ID) {
            DebtPosition memory debtPosition = state.createDebtAndCreditPositions({
                lender: msg.sender,
                borrower: params.borrower,
                faceValue: creditAmountOut,
                dueDate: params.dueDate
            });
            state.data.debtToken.mint(params.borrower, debtPosition.getTotalDebt());
        } else {
            state.createCreditPosition({
                exitCreditPositionId: params.creditPositionId,
                lender: msg.sender,
                credit: creditAmountOut
            });
        }

        state.transferBorrowAToken(msg.sender, params.borrower, cashAmountIn - fees);
        state.transferBorrowAToken(msg.sender, state.feeConfig.feeRecipient, fees);
    }
}
