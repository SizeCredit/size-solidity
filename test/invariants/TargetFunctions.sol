// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Helper} from "./Helper.sol";
import {Properties} from "./Properties.sol";
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import "@crytic/properties/contracts/util/Hevm.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Deploy} from "@test/Deploy.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

abstract contract TargetFunctions is Deploy, Helper, Properties, BaseTargetFunctions {
    event L4(uint256 a, uint256 b, uint256 c, uint256 d);

    function setup() internal override {
        setup(address(this), address(0x1), address(this));
        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            usdc.mint(user, MAX_AMOUNT_USDC / 3);

            hevm.prank(user);
            weth.deposit{value: MAX_AMOUNT_WETH / 3}();
        }
    }

    function deposit(address token, uint256 amount) public getSender {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);
        uint256 maxAmount = token == address(weth) ? MAX_AMOUNT_WETH / 3 : MAX_AMOUNT_USDC / 3;
        amount = between(amount, maxAmount / 2, maxAmount);

        __before();

        hevm.prank(sender);
        IERC20Metadata(token).approve(address(size), amount);
        hevm.prank(sender);
        size.deposit(DepositParams({token: token, amount: amount}));

        __after();

        if (token == address(weth)) {
            eq(_after.sender.collateralAmount, _before.sender.collateralAmount + amount, DEPOSIT_01);
            eq(_after.senderCollateralAmount, _before.senderCollateralAmount - amount, DEPOSIT_01);
        } else {
            eq(_after.sender.borrowAmount, _before.sender.borrowAmount + amount * 1e12, DEPOSIT_01);
            eq(_after.senderBorrowAmount, _before.senderBorrowAmount - amount, DEPOSIT_01);
        }
    }

    // function withdraw(address token, uint256 amount) public getSender {
    //     token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);

    //     __before();

    //     uint256 maxAmount = token == address(weth) ? MAX_AMOUNT_WETH : MAX_AMOUNT_USDC;
    //     amount = between(amount, 0, maxAmount);
    //     hevm.prank(sender);
    //     size.withdraw(WithdrawParams({token: token, amount: amount}));

    //     __after();

    //     if (token == address(weth)) {
    //         eq(_after.sender.collateralAmount, _before.sender.collateralAmount - amount, WITHDRAW_01);
    //         eq(_after.senderCollateralAmount, _before.senderCollateralAmount + amount, WITHDRAW_01);
    //     } else {
    //         eq(_after.sender.borrowAmount, _before.sender.borrowAmount - amount * 1e12, WITHDRAW_01);
    //         eq(_after.senderBorrowAmount, _before.senderBorrowAmount + amount, WITHDRAW_01);
    //     }
    // }

    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256 n,
        uint256 seedVirtualCollateralLoanIds
    ) public getSender {
        __before();

        lender = _getRandomSender(lender);
        amount = between(amount, 0, MAX_AMOUNT_USDC * 1e12 / 100);
        dueDate = between(dueDate, block.timestamp, block.timestamp + MAX_DURATION);

        uint256[] memory virtualCollateralLoanIds;
        if (_before.activeLoans > 0) {
            n = between(n, 1, _before.activeLoans);
            virtualCollateralLoanIds = _getRandomVirtualCollateralLoanIds(n, seedVirtualCollateralLoanIds);
        }

        hevm.prank(sender);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralLoanIds: virtualCollateralLoanIds
            })
        );

        __after();

        if (lender == sender) {
            eq(_after.sender.borrowAmount, _before.sender.borrowAmount, BORROW_03);
        } else {
            gt(_after.sender.borrowAmount, _before.sender.borrowAmount, BORROW_01);
        }

        if (amount > size.config().minimumCredit) {
            if (virtualCollateralLoanIds.length > 0) {
                gte(_after.activeLoans, _before.activeLoans + 1, BORROW_02);
            } else {
                eq(_after.activeLoans, _before.activeLoans + 1, BORROW_02);
            }
        }
    }

    // function borrowAsLimitOrder(uint256 maxAmount, uint256 yieldCurveSeed) public getSender {
    //     __before();

    //     maxAmount = between(maxAmount, 0, MAX_AMOUNT_USDC * 1e12);
    //     YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

    //     hevm.prank(sender);
    //     size.borrowAsLimitOrder(BorrowAsLimitOrderParams({maxAmount: maxAmount, curveRelativeTime: curveRelativeTime}));

    //     __after();
    // }

    // function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount, bool exactAmountIn)
    //     public
    //     getSender
    // {
    //     __before();

    //     borrower = _getRandomSender(borrower);
    //     dueDate = between(dueDate, block.timestamp, block.timestamp + MAX_DURATION);
    //     amount = between(amount, 0, _before.sender.borrowAmount / 10);

    //     hevm.prank(sender);
    //     size.lendAsMarketOrder(
    //         LendAsMarketOrderParams({borrower: borrower, dueDate: dueDate, amount: amount, exactAmountIn: exactAmountIn})
    //     );

    //     __after();

    //     if (sender == borrower) {
    //         eq(_after.sender.borrowAmount, _before.sender.borrowAmount, BORROW_03);
    //     } else {
    //         lt(_after.sender.borrowAmount, _before.sender.borrowAmount, BORROW_01);
    //     }
    //     eq(_after.activeLoans, _before.activeLoans + 1, BORROW_02);
    // }

    function lendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, uint256 yieldCurveSeed) public getSender {
        __before();

        maxAmount = between(maxAmount, _before.sender.borrowAmount / 2, _before.sender.borrowAmount);
        maxDueDate = between(maxDueDate, block.timestamp, block.timestamp + MAX_DURATION);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({maxAmount: maxAmount, maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime})
        );

        __after();
    }

    // function borrowerExit(uint256 loanId, address borrowerToExitTo) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);
    //     borrowerToExitTo = _getRandomSender(borrowerToExitTo);

    //     hevm.prank(sender);
    //     size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));

    //     __after(loanId);

    //     if (borrowerToExitTo == sender) {
    //         eq(_after.sender.debtAmount, _before.sender.debtAmount, BORROWER_EXIT_01);
    //     } else {
    //         lt(_after.sender.debtAmount, _before.sender.debtAmount, BORROWER_EXIT_01);
    //     }
    // }

    // function repay(uint256 loanId, uint256 amount) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);

    //     hevm.prank(sender);
    //     size.repay(RepayParams({loanId: loanId, amount: amount}));

    //     __after(loanId);

    //     lt(_after.sender.borrowAmount, _before.sender.borrowAmount, REPAY_01);
    //     gt(_after.protocolBorrowAmount, _before.protocolBorrowAmount, REPAY_01);
    //     lt(_after.sender.debtAmount, _before.sender.debtAmount, REPAY_02);
    // }

    // function claim(uint256 loanId) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);

    //     hevm.prank(sender);
    //     size.claim(ClaimParams({loanId: loanId}));

    //     __after(loanId);

    //     gte(_after.sender.borrowAmount, _before.sender.borrowAmount, BORROW_01);
    //     t(size.isFOL(loanId), CLAIM_02);
    // }

    // function liquidateLoan(uint256 loanId) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);

    //     hevm.prank(sender);
    //     size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

    //     __after(loanId);

    //     gt(_after.sender.collateralAmount, _before.sender.collateralAmount, LIQUIDATE_01);
    //     lt(_after.sender.borrowAmount, _before.sender.borrowAmount, LIQUIDATE_02);
    //     lt(_after.borrower.debtAmount, _before.borrower.debtAmount, LIQUIDATE_02);
    //     t(_before.isSenderLiquidatable, LIQUIDATE_03);
    // }

    // function selfLiquidateLoan(uint256 loanId) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);

    //     hevm.prank(sender);
    //     size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));

    //     __after(loanId);

    //     lt(_after.sender.collateralAmount, _before.sender.collateralAmount, LIQUIDATE_01);
    //     lt(_after.sender.debtAmount, _before.sender.debtAmount, LIQUIDATE_02);
    // }

    // function liquidateLoanWithReplacement(uint256 loanId, address borrower) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);
    //     borrower = _getRandomSender(borrower);

    //     hevm.prank(sender);
    //     size.liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: borrower}));

    //     __after(loanId);

    //     lt(_after.borrower.debtAmount, _before.borrower.debtAmount, LIQUIDATE_02);
    // }

    // function moveToVariablePool(uint256 loanId) public getSender {
    //     __before(loanId);

    //     precondition(_before.activeLoans > 0);

    //     loanId = between(loanId, 0, _before.activeLoans - 1);

    //     hevm.prank(sender);
    //     size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));

    //     __after(loanId);
    // }

    // function setPrice(uint256 price) public {
    //     uint256 oldPrice = priceFeed.getPrice();
    //     price = between(price, oldPrice * 1e18 / 1.2e18, priceFeed.getPrice() * 1.2e18 / 1e18);

    //     priceFeed.setPrice(price);
    // }
}
