// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math, Rounding} from "@src/libraries/MathLibrary.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";
import {ScaledToken} from "@src/token/ScaledToken.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct WithdrawVariableParams {
    address token;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC or 1_000e18 for 1000 WETH)
}

library WithdrawVariable {
    using SafeERC20 for IERC20Metadata;
    using VariableLibrary for State;

    function validateWithdrawVariable(State storage state, WithdrawVariableParams calldata params) external view {
        // validte msg.sender

        // validate token
        if (
            params.token != address(state._general.collateralAsset)
                && params.token != address(state._general.borrowAsset)
        ) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeWithdrawVariable(State storage state, WithdrawVariableParams calldata params) external {
        state.updateLiquidityIndex();

        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = Math.amountToWad(params.amount, IERC20Metadata(params.token).decimals());

        if (params.token == address(state._general.collateralAsset)) {
            state._variable.collateralToken.burn(msg.sender, wad);
        } else {
            state._variable.scaledBorrowToken.burnScaled(msg.sender, wad, state._variable.liquidityIndexBorrowRAY);
        }
        token.safeTransfer(msg.sender, params.amount);

        emit Events.WithdrawVariable(params.token, wad);
    }
}
