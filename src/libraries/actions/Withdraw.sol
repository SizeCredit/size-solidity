// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {VaultLibrary, Vault} from "@src/libraries/VaultLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct WithdrawParams {
    address account;
    address token;
    uint256 value;
}

library Withdraw {
    using LoanLibrary for Loan;
    using VaultLibrary for Vault;
    using SafeERC20 for IERC20Metadata;

    function validateWithdraw(State storage state, WithdrawParams memory params) external view {
        // validte account

        // validate token
        if (params.token != address(state.collateralAsset) && params.token != address(state.borrowAsset)) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate value
        if (params.value == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeWithdraw(State storage state, WithdrawParams memory params) external {
        User storage user = state.users[params.account];
        Vault storage vault = params.token == address(state.collateralAsset) ? user.collateralAsset : user.borrowAsset;
        IERC20Metadata token = IERC20Metadata(params.token);
        uint256 wad = VaultLibrary.valueToWad(params.value, IERC20Metadata(params.token).decimals());

        vault.free -= wad;
        token.safeTransfer(params.account, params.value);

        emit Events.Withdraw(params.token, wad);
    }
}
