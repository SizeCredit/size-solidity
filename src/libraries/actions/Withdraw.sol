// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Error} from "@src/libraries/Error.sol";

struct WithdrawParams {
    address user;
    address token;
    uint256 value;
}

library Withdraw {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;
    using SafeERC20 for IERC20Metadata;

    function validateWithdraw(State storage state, WithdrawParams memory params) external view {
        // validte user

        // validate token
        if (params.token != address(state.collateralAsset) && params.token != address(state.borrowAsset)) {
            revert Error.INVALID_TOKEN(params.token);
        }

        // validate value
        if (params.value == 0) {
            revert Error.NULL_AMOUNT();
        }
    }

    function executeWithdraw(State storage state, WithdrawParams memory params) external {
        uint256 wad = RealCollateralLibrary.valueToWad(params.value, IERC20Metadata(params.token).decimals());
        if (params.token == address(state.collateralAsset)) {
            state.users[params.user].collateralAsset.free -= wad;
            state.collateralAsset.safeTransfer(params.user, params.value);
        } else {
            state.users[params.user].borrowAsset.free -= wad;
            state.borrowAsset.safeTransfer(params.user, params.value);
        }
    }
}
