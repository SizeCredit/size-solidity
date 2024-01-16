// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayVariableParams {
    uint256 amount;
}

library RepayVariable {
    using SafeERC20 for IERC20Metadata;
    using VariablePoolLibrary for State;

    function validateRepayVariable(State storage, RepayVariableParams calldata params) external pure {
        // validte msg.sender

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeRepayVariable(State storage state, RepayVariableParams calldata params) external {
        state.updateLiquidityIndex();
        state.v.scaledDebtToken.burnScaled(msg.sender, params.amount, state.v.liquidityIndexBorrow);
    }
}
