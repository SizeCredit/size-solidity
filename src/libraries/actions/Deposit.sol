// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {Math} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Error} from "@src/libraries/Error.sol";

struct DepositParams {
    address user;
    uint256 cash;
    uint256 eth;
}

library Deposit {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function validateDeposit(State storage, DepositParams memory params) external pure {
        // validte user

        // validate cash
        // validate eth
        if (params.cash == 0 && params.eth == 0) {
            revert Error.NULL_AMOUNT();
        }
    }

    function executeDeposit(State storage state, DepositParams memory params) external {
        state.users[params.user].cash.free += params.cash;
        state.users[params.user].eth.free += params.eth;
    }
}
