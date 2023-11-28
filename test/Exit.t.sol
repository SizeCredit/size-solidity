// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

contract ExitTest is BaseTest {
    function test_Exit_exit_transfer_cash_from_loanOffer_to_sender_properties() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);

        User memory aliceUserBefore = size.getUser(alice);
        User memory bobUserBefore = size.getUser(bob);
        User memory candyUserBefore = size.getUser(candy);

        address[] memory lendersToExitTo = new address[](1);
        lendersToExitTo[0] = candy;

        LoanOffer memory loanOfferBefore = size.getLoanOffer(candy);
        Loan memory loanBefore = size.getLoan(loanId);
        uint256 loansBefore = size.activeLoans();

        _exit(alice, loanId, 10e18, 12, lendersToExitTo);

        LoanOffer memory loanOfferAfter = size.getLoanOffer(candy);
        Loan memory loanAfter = size.getLoan(loanId);
        uint256 loansAfter = size.activeLoans();

        User memory aliceUserAfter = size.getUser(alice);
        User memory bobUserAfter = size.getUser(bob);
        User memory candyUserAfter = size.getUser(candy);

        assertLt(candyUserAfter.borrowAsset.free, candyUserBefore.borrowAsset.free);
        assertGt(aliceUserAfter.borrowAsset.free, aliceUserBefore.borrowAsset.free);
        assertLt(loanOfferAfter.maxAmount, loanOfferBefore.maxAmount);
        assertGt(loanAfter.amountFVExited, loanBefore.amountFVExited);
        assertEq(bobUserBefore, bobUserAfter);
        assertGt(loansAfter, loansBefore);
    }

    // @audit exit to self decreases the maxAmount of the loanOffer and increases the amountFVExited of the loan (apparently, no benefit to the lender)
    function test_Exit_exit_to_self_is_possible_properties() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 30e18, 12);

        User memory aliceUserBefore = size.getUser(alice);
        User memory bobUserBefore = size.getUser(bob);

        address[] memory lendersToExitTo = new address[](1);
        lendersToExitTo[0] = alice;

        LoanOffer memory loanOfferBefore = size.getLoanOffer(alice);
        Loan memory loanBefore = size.getLoan(loanId);
        uint256 loansBefore = size.activeLoans();

        _exit(alice, loanId, 30e18, 12, lendersToExitTo);

        LoanOffer memory loanOfferAfter = size.getLoanOffer(alice);
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
