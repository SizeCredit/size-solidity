// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowVariableParams {
    uint256 amount;
}

library BorrowVariable {
    using SafeERC20 for IERC20Metadata;
    using VariableLibrary for State;

    function validateBorrowVariable(State storage, BorrowVariableParams calldata params) external pure {
        // validte msg.sender

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeBorrowVariable(State storage state, BorrowVariableParams calldata params) external {
        state.updateLiquidityIndex();
        state._variable.scaledDebtToken.mintScaled(msg.sender, params.amount, state._variable.indexBorrowRAY);

        // TODO check order of these operations:
        state._variable.scaledBorrowToken.mintScaled(msg.sender, params.amount, state._variable.indexBorrowRAY);
        state.updateInterestRates();

        emit Events.BorrowVariable(params.amount);
    }
}
