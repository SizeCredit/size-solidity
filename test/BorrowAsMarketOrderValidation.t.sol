// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract BorrowAsMarketOrderValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;

    function test_BorrowAsMarketOrderValidation() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e4, 12);
        _lendAsLimitOrder(bob, 100e18, 5, 0.03e4, 5);
        _lendAsLimitOrder(candy, 100e18, 10, 0.03e4, 10);
        uint256 loanId = _borrowAsMarketOrder(alice, candy, 1e18, 10);

        uint256 amount = 10e18;
        uint256 dueDate = 12;
        bool exactAmountIn = false;
        uint256[] memory virtualCollateralLoansIds;

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LOAN_OFFER.selector, address(0)));
        size.borrowAsMarketOrder(address(0), amount, dueDate, exactAmountIn, virtualCollateralLoansIds);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.borrowAsMarketOrder(alice, 0, dueDate, exactAmountIn, virtualCollateralLoansIds);

        vm.expectRevert(abi.encodeWithSelector(Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT.selector, 110e18, 100e18));
        size.borrowAsMarketOrder(alice, 110e18, dueDate, exactAmountIn, virtualCollateralLoansIds);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        size.borrowAsMarketOrder(alice, 100e18, 0, exactAmountIn, virtualCollateralLoansIds);

        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector, 13, 12));
        size.borrowAsMarketOrder(alice, 100e18, 13, exactAmountIn, virtualCollateralLoansIds);

        virtualCollateralLoansIds = new uint256[](1);
        virtualCollateralLoansIds[0] = loanId;
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROWER_IS_NOT_LENDER.selector, bob, candy));
        size.borrowAsMarketOrder(alice, 100e18, dueDate, exactAmountIn, virtualCollateralLoansIds);

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_LOWER_THAN_LOAN_DUE_DATE.selector, 4, 10));
        size.borrowAsMarketOrder(bob, 100e18, 4, exactAmountIn, virtualCollateralLoansIds);
    }
}
