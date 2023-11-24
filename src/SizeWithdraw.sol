// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {SizeView} from "./SizeView.sol";
import {Math} from "./libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "./interfaces/ISize.sol";

struct WithdrawParams {
    address user;
    uint256 cash;
    uint256 eth;
}

abstract contract SizeWithdraw is SizeStorage, SizeView, ISize {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _validateWithdraw(WithdrawParams memory params) internal pure {
        // validte user

        // validate cash
        // validate eth
        if (params.cash == 0 && params.eth == 0) {
            revert ERROR_NULL_AMOUNT();
        }
    }

    function _executeWithdraw(WithdrawParams memory params) internal {
        users[params.user].cash.free -= params.cash;
        users[params.user].eth.free -= params.eth;
    }
}
