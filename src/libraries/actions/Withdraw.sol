// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {VaultLibrary, Vault} from "@src/libraries/VaultLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct WithdrawParams {
    address user;
    address token;
    uint256 value;
}

library Withdraw {
    using LoanLibrary for Loan;
    using VaultLibrary for Vault;
    using SafeERC20 for IERC20Metadata;

    function validateWithdraw(State storage state, WithdrawParams memory params) external view {
        // validte user

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
        User storage user = state.users[params.user];
        if (params.token == address(state.collateralAsset)) {
            user.collateralAsset.free -= VaultLibrary.valueToWad(params.value, state.collateralAsset.decimals());
            state.collateralAsset.safeTransfer(params.user, params.value);
        } else {
            user.borrowAsset.free -= VaultLibrary.valueToWad(params.value, state.borrowAsset.decimals());
            state.borrowAsset.safeTransfer(params.user, params.value);
        }
    }
}
