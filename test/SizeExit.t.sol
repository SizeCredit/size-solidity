// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

contract SizeExitTest is BaseTest {
    function test_SizeExit_exit_transfer_cash_from_loanOffer_to_sender_properties() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        uint256 loanOfferId = _lendAsLimitOrder(alice, 100e18, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, loanOfferId, 100e18, 12);
        uint256 loanOfferId2 = _lendAsLimitOrder(candy, 100e18, 0.03e18, 12);

        User memory aliceUserBefore = size.getUser(alice);
        User memory bobUserBefore = size.getUser(bob);
        User memory candyUserBefore = size.getUser(candy);

        uint256[] memory loanOfferIds = new uint256[](1);
        loanOfferIds[0] = loanOfferId2;

        LoanOffer memory loanOfferBefore = size.getLoanOffer(loanOfferId2);
        Loan memory loanBefore = size.getLoan(loanId);
        uint256 loansBefore = size.activeLoans();

        _exit(alice, loanId, 10e18, 12, loanOfferIds);

        LoanOffer memory loanOfferAfter = size.getLoanOffer(loanOfferId2);
        Loan memory loanAfter = size.getLoan(loanId);
        uint256 loansAfter = size.activeLoans();

        User memory aliceUserAfter = size.getUser(alice);
        User memory bobUserAfter = size.getUser(bob);
        User memory candyUserAfter = size.getUser(candy);

        assertLt(candyUserAfter.cash.free, candyUserBefore.cash.free);
        assertGt(aliceUserAfter.cash.free, aliceUserBefore.cash.free);
        assertLt(loanOfferAfter.maxAmount, loanOfferBefore.maxAmount);
        assertGt(loanAfter.amountFVExited, loanBefore.amountFVExited);
        assertEq(bobUserBefore, bobUserAfter);
        assertGt(loansAfter, loansBefore);
    }

    // @audit exit to self decreases the maxAmount of the loanOffer and increases the amountFVExited of the loan (apparently, no benefit to the lender)
    function test_SizeExit_exit_to_self_is_possible_properties() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        uint256 loanOfferId = _lendAsLimitOrder(alice, 100e18, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, loanOfferId, 30e18, 12);

        User memory aliceUserBefore = size.getUser(alice);
        User memory bobUserBefore = size.getUser(bob);

        uint256[] memory loanOfferIds = new uint256[](1);
        loanOfferIds[0] = loanOfferId;

        LoanOffer memory loanOfferBefore = size.getLoanOffer(loanOfferId);
        Loan memory loanBefore = size.getLoan(loanId);
        uint256 loansBefore = size.activeLoans();

        _exit(alice, loanId, 30e18, 12, loanOfferIds);

        LoanOffer memory loanOfferAfter = size.getLoanOffer(loanOfferId);
        Loan memory loanAfter = size.getLoan(loanId);
        uint256 loansAfter = size.activeLoans();

        User memory aliceUserAfter = size.getUser(alice);
        User memory bobUserAfter = size.getUser(bob);

        assertEq(aliceUserAfter, aliceUserBefore);
        assertLt(loanOfferAfter.maxAmount, loanOfferBefore.maxAmount);
        assertGt(loanAfter.amountFVExited, loanBefore.amountFVExited);
        assertEq(bobUserBefore, bobUserAfter);
        assertGt(loansAfter, loansBefore);
    }
}
