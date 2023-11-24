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

struct LiquidateLoanParams {
    uint256 loanId;
    address liquidator;
}

abstract contract SizeLiquidateLoan is SizeStorage, SizeView, ISize {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _validateLiquidateLoan(LiquidateLoanParams memory params) internal view {}

    function _executeLiquidateLoan(LiquidateLoanParams memory params) internal {}
}
