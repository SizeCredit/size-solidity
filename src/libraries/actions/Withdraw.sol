// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {MathLibrary} from "@src/libraries/MathLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct WithdrawParams {
    address token;
    uint256 amount;
}

library Withdraw {
    using LoanLibrary for Loan;
    using SafeERC20 for IERC20Metadata;

    function validateWithdraw(State storage state, WithdrawParams memory params) external view {
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

    function executeWithdraw(State storage state, WithdrawParams memory params) external {
        NonTransferrableToken nonTransferrableToken = params.token == address(state.collateralAsset)
            ? NonTransferrableToken(state.collateralToken)
            : NonTransferrableToken(state.borrowToken);
        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = MathLibrary.amountToWad(params.amount, IERC20Metadata(params.token).decimals());

        nonTransferrableToken.burn(msg.sender, wad);
        token.safeTransfer(msg.sender, params.amount);

        emit Events.Withdraw(params.token, wad);
    }
}
