// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositVariableParams {
    address token;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC or 1_000e18 for 1000 WETH)
}

library DepositVariable {
    using SafeERC20 for IERC20Metadata;
    using VariableLibrary for State;

    function validateDepositVariable(State storage state, DepositVariableParams calldata params) external view {
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

    function executeDepositVariable(State storage state, DepositVariableParams calldata params) external {
        // @audit pass token as arg?
        state.updateLiquidityIndex();

        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = ConversionLibrary.amountToWad(params.amount, IERC20Metadata(params.token).decimals());

        token.safeTransferFrom(msg.sender, address(this), params.amount);
        if (params.token == address(state._general.collateralAsset)) {
            state._variable.collateralToken.mint(msg.sender, wad);
        } else {
            state._variable.scaledBorrowToken.mintScaled(msg.sender, wad, state._variable.indexBorrowRAY);
        }

        emit Events.DepositVariable(params.token, wad);
    }
}
