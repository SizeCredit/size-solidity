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

    function test_SizeExit_exit_transfer_cash_from_loanOffer_to_sender()
        public
    {
        _deposit(alice);
        _deposit(bob);
        _deposit(candy);
        uint256 loanOfferId = _lendAsLimitOrder(alice);
        uint256 loanId = _borrowAsMarketOrder(bob, loanOfferId);
        uint256 loanOfferId2 = _lendAsLimitOrder(candy);

        User memory aliceUserBefore = size.getUser(alice);
        User memory bobUserBefore = size.getUser(bob);
        User memory candyUserBefore = size.getUser(candy);

        uint256[] memory loanOfferIds = new uint256[](1);
        loanOfferIds[0] = loanOfferId2;

        LoanOffer memory loanOfferBefore = size.getLoanOffer(loanOfferId2);
        Loan memory loanBefore = size.getLoan(loanId);
        uint256 loansBefore = size.activeLoans();

        _exit(alice, loanId, loanOfferIds);

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
        assertEqUser(bobUserBefore, bobUserAfter);
        assertGt(loansAfter, loansBefore);
    }
}
