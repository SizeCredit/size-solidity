// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math, Rounding} from "@src/libraries/MathLibrary.sol";

import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";
import {ScaledToken} from "@src/token/ScaledToken.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositVariableParams {
    address token;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC or 1_000e18 for 1000 WETH)
}

library DepositVariable {
    using SafeERC20 for IERC20Metadata;
    using VariablePoolLibrary for State;

    function validateDepositVariable(State storage state, DepositVariableParams calldata params) external view {
        // validte msg.sender

        // validate token
        if (params.token != address(state.g.collateralAsset) && params.token != address(state.g.borrowAsset)) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeDepositVariable(State storage state, DepositVariableParams calldata params) external {
        // @audit pass token as arg?
        state.updateLiquidityIndex();

        ScaledToken scaledToken = params.token == address(state.g.collateralAsset)
            ? ScaledToken(state.v.scaledSupplyToken)
            : ScaledToken(state.v.scaledBorrowToken);
        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = Math.amountToWad(params.amount, IERC20Metadata(params.token).decimals());

        token.safeTransferFrom(msg.sender, address(this), params.amount);
        scaledToken.mintScaled(msg.sender, wad, state.v.liquidityIndexSupply, Rounding.DOWN);

        emit Events.DepositVariable(params.token, wad);
    }
}
