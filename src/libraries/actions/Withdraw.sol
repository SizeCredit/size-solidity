// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {Math} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import "@src/Errors.sol";

struct WithdrawParams {
    address user;
    uint256 cash;
    uint256 eth;
}

library Withdraw {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function validateWithdraw(State storage, WithdrawParams memory params) external pure {
        // validte user

        // validate cash
        // validate eth
        if (params.cash == 0 && params.eth == 0) {
            revert ERROR_NULL_AMOUNT();
        }
    }

    function executeWithdraw(State storage state, WithdrawParams memory params) external {
        state.users[params.user].cash.free -= params.cash;
        state.users[params.user].eth.free -= params.eth;
    }
}
