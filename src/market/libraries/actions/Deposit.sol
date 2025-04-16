// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@src/market/interfaces/IWETH.sol";
import {CapsLibrary} from "@src/market/libraries/CapsLibrary.sol";

import {State} from "@src/market/SizeStorage.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {DepositTokenLibrary} from "@src/market/libraries/DepositTokenLibrary.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

struct DepositParams {
    // The token to deposit
    address token;
    // The amount to deposit
    uint256 amount;
    // The account to deposit the tokens to
    address to;
}

struct DepositOnBehalfOfParams {
    // The parameters for the deposit
    DepositParams params;
    // The account to transfer the tokens from
    address onBehalfOf;
}

/// @title Deposit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for depositing tokens into the protocol
library Deposit {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IWETH;

    using DepositTokenLibrary for State;
    using CapsLibrary for State;

    /// @notice Validates the deposit parameters
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for depositing tokens
    function validateDeposit(State storage state, DepositOnBehalfOfParams memory externalParams) external view {
        DepositParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.DEPOSIT)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.DEPOSIT));
        }

        // validate msg.value
        if (
            msg.value != 0
                && (msg.value != params.amount || params.token != address(state.data.weth) || onBehalfOf != msg.sender)
        ) {
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

    /// @notice Executes the deposit
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for depositing tokens
    function executeDeposit(State storage state, DepositOnBehalfOfParams memory externalParams) public {
        DepositParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        address from = onBehalfOf;
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
            state.depositUnderlyingBorrowTokenToVault(from, params.to, amount);
            // borrow aToken cap is not validated in multicall,
            //   since users must be able to deposit more tokens to repay debt
            if (!state.data.isMulticall) {
                state.validateborrowTokenCap();
            }
        } else {
            state.depositUnderlyingCollateralToken(from, params.to, amount);
        }

        emit Events.Deposit(msg.sender, onBehalfOf, params.token, params.to, amount);
    }
}
