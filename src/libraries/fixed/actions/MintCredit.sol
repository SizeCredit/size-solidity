// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";

struct MintCreditParams {
    uint256 amount;
    uint256 dueDate;
}

library MintCredit {
    using AccountingLibrary for State;
    using LoanLibrary for DebtPosition;

    function validateMintCredit(State storage state, MintCreditParams calldata params) external view {
        if (!state.data.isMulticall) {
            revert Errors.NOT_SUPPORTED();
        }

        // validate msg.sender
        // N/A

        // validate amount
        if (params.amount < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(params.amount, state.riskConfig.minimumCreditBorrowAToken);
        }

        // validate dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
    }

    function executeMintCredit(State storage state, MintCreditParams calldata params) external {
        DebtPosition memory debtPosition = state.createDebtAndCreditPositions({
            lender: msg.sender,
            borrower: msg.sender,
            faceValue: params.amount,
            dueDate: params.dueDate
        });
        state.data.debtToken.mint(msg.sender, debtPosition.getTotalDebt());

        emit Events.MintCredit(params.amount, params.dueDate);
    }
}
