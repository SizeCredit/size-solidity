// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {MathLibrary} from "@src/libraries/MathLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositParams {
    address token;
    uint256 amount;
}

library Deposit {
    using SafeERC20 for IERC20Metadata;

    function validateDeposit(State storage state, DepositParams memory params) external view {
        // validte msg.sender

        // validate token
        if (params.token != address(state.collateralAsset) && params.token != address(state.borrowAsset)) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeDeposit(State storage state, DepositParams memory params) external {
        NonTransferrableToken nonTransferrableToken = params.token == address(state.collateralAsset)
            ? NonTransferrableToken(state.collateralToken)
            : NonTransferrableToken(state.borrowToken);
        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = MathLibrary.amountToWad(params.amount, IERC20Metadata(params.token).decimals());

        token.safeTransferFrom(msg.sender, address(this), params.amount);
        nonTransferrableToken.mint(msg.sender, wad);

        emit Events.Deposit(params.token, wad);
    }
}
