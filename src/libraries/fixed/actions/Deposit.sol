// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositParams {
    address token;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC or 1_000e18 for 1000 WETH)
    address to;
}

library Deposit {
    using SafeERC20 for IERC20Metadata;

    function validateDeposit(State storage state, DepositParams calldata params) external view {
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

        // validate to
        if (params.to == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function executeDeposit(State storage state, DepositParams calldata params, address from) public {
        NonTransferrableToken nonTransferrableToken = params.token == address(state._general.collateralAsset)
            ? NonTransferrableToken(state._fixed.collateralToken)
            : NonTransferrableToken(state._fixed.borrowToken);
        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = ConversionLibrary.amountToWad(params.amount, IERC20Metadata(params.token).decimals());

        token.safeTransferFrom(from, address(this), params.amount);
        nonTransferrableToken.mint(params.to, wad);

        emit Events.Deposit(params.token, params.to, wad);
    }

    function executeDeposit(State storage state, DepositParams calldata params) external {
        return executeDeposit(state, params, msg.sender);
    }
}
