// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";

import {State} from "@src/SizeStorage.sol";

import {CollateralLibrary} from "@src/libraries/fixed/CollateralLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct DepositParams {
    address token;
    uint256 amount;
    address to;
}

library Deposit {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IWETH;
    using VariablePoolLibrary for State;
    using CollateralLibrary for State;

    function validateDeposit(State storage state, DepositParams calldata params) external view {
        // validate msg.sender
        // N/A

        // validate msg.value
        if (msg.value != 0 && (msg.value != params.amount || params.token != address(state.data.weth))) {
            revert Errors.INVALID_MSG_VALUE(msg.value);
        }

        // validate token
        if (
            params.token != address(state.data.underlyingCollateralToken)
                && params.token != address(state.data.underlyingBorrowToken)
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

    function executeDeposit(State storage state, DepositParams calldata params) public {
        address from = msg.sender;
        uint256 amount = params.amount;
        if (msg.value > 0) {
            // do not trust msg.value (see `Multicall.sol`)
            amount = address(this).balance;
            // slither-disable-next-line arbitrary-send-eth
            state.data.weth.deposit{value: amount}();
            state.data.weth.forceApprove(address(this), amount);
            from = address(this);
        }

        if (params.token == address(state.data.underlyingBorrowToken)) {
            state.depositUnderlyingBorrowTokenToVariablePool(from, params.to, amount);
        } else {
            state.depositUnderlyingCollateralToken(from, params.to, amount);
        }

        emit Events.Deposit(params.token, params.to, amount);
    }
}
