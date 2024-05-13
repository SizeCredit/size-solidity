// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {Math} from "@src/libraries/Math.sol";
import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

import {DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";

struct MintCreditParams {
    uint256 amount;
    uint256 dueDate;
}

library MintCredit {
    using AccountingLibrary for State;
    using LoanLibrary for DebtPosition;

    function validateMintCredit(State storage, MintCreditParams calldata params) external view {
        // validate msg.sender
        // N/A

        // validate amount

        // validate dueDate
        if (params.dueDate < block.timestamp && params.dueDate != 0) {
            // `dueDate == 0` means `block.timestamp`
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
    }

    function executeMintCredit(State storage state, MintCreditParams calldata params) external {
        uint256 dueDate = Math.max(block.timestamp, params.dueDate);

        DebtPosition memory debtPosition = state.createDebtAndCreditPositions({
            lender: msg.sender,
            borrower: msg.sender,
            faceValue: params.amount,
            dueDate: dueDate
        });
        state.data.debtToken.mint(msg.sender, debtPosition.getTotalDebt());

        emit Events.MintCredit(params.amount, params.dueDate);
    }
}
