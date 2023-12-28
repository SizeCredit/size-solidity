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
    function setup() internal override {
        setup(address(this), address(0x1), address(this));
        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        for (uint256 i = 0; i < users.length; i++) {
            usdc.mint(users[i], MAX_AMOUNT_USDC / 3);

            hevm.prank(users[i]);
            weth.deposit{value: MAX_AMOUNT_WETH / 3}();
        }
    }

    function deposit(address token, uint256 amount) public getUser {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);
        uint256 maxAmount = token == address(weth) ? MAX_AMOUNT_WETH : MAX_AMOUNT_USDC;
        amount = between(amount, 0, maxAmount);

        __before();

        hevm.prank(user);
        IERC20Metadata(token).approve(address(size), amount);
        hevm.prank(user);
        size.deposit(DepositParams({token: token, amount: amount}));

        __after();

        if (token == address(weth)) {
            eq(_after.user.collateralAmount, _before.user.collateralAmount + amount, DEPOSIT_01);
            eq(_after.senderCollateralAmount, _before.senderCollateralAmount - amount, DEPOSIT_01);
        } else {
            eq(_after.user.borrowAmount, _before.user.borrowAmount + amount * 1e12, DEPOSIT_01);
            eq(_after.senderBorrowAmount, _before.senderBorrowAmount - amount, DEPOSIT_01);
        }
    }

    function withdraw(address token, uint256 amount) public getUser {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);

        __before();

        uint256 maxAmount = token == address(weth) ? MAX_AMOUNT_WETH : MAX_AMOUNT_USDC;
        amount = between(amount, 0, maxAmount);
        hevm.prank(user);
        size.withdraw(WithdrawParams({token: token, amount: amount}));

        __after();

        if (token == address(weth)) {
            eq(_after.user.collateralAmount, _before.user.collateralAmount - amount, WITHDRAW_01);
            eq(_after.senderCollateralAmount, _before.senderCollateralAmount + amount, WITHDRAW_01);
        } else {
            eq(_after.user.borrowAmount, _before.user.borrowAmount - amount * 1e12, WITHDRAW_01);
            eq(_after.senderBorrowAmount, _before.senderBorrowAmount + amount, WITHDRAW_01);
        }
    }

    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256 n,
        uint256 seedVirtualCollateralLoanIds
    ) public getUser {
        __before();

        lender = _getRandomUser(lender);
        amount = between(amount, 0, MAX_AMOUNT_USDC);
        dueDate = between(dueDate, 0, MAX_TIMESTAMP);

        n = between(n, 0, size.activeLoans());
        uint256[] memory virtualCollateralLoanIds = _getRandomVirtualCollateralLoanIds(n, seedVirtualCollateralLoanIds);

        hevm.prank(user);
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
    }

    function borrowAsLimitOrder(uint256 maxAmount, uint256 yieldCurveSeed) public getUser {
        __before();

        maxAmount = between(maxAmount, 0, MAX_AMOUNT_USDC);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(user);
        size.borrowAsLimitOrder(BorrowAsLimitOrderParams({maxAmount: maxAmount, curveRelativeTime: curveRelativeTime}));

        __after();
    }

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount, bool exactAmountIn) public getUser {
        __before();

        borrower = _getRandomUser(borrower);
        dueDate = between(dueDate, 0, MAX_TIMESTAMP);
        amount = between(amount, 0, MAX_AMOUNT_USDC);

        hevm.prank(user);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: borrower, dueDate: dueDate, amount: amount, exactAmountIn: exactAmountIn})
        );

        __after();
    }

    function lendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, uint256 yieldCurveSeed) public getUser {
        __before();

        maxAmount = between(maxAmount, 0, MAX_AMOUNT_USDC);
        maxDueDate = between(maxDueDate, 0, MAX_TIMESTAMP);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(user);
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({maxAmount: maxAmount, maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime})
        );

        __after();
    }

    function borrowerExit(uint256 loanId, address borrowerToExitTo) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());
        borrowerToExitTo = _getRandomUser(borrowerToExitTo);

        hevm.prank(user);
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));

        __after();
    }

    function repay(uint256 loanId) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());

        hevm.prank(user);
        size.repay(RepayParams({loanId: loanId}));

        __after();
    }

    function claim(uint256 loanId) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());

        hevm.prank(user);
        size.claim(ClaimParams({loanId: loanId}));

        __after();
    }

    function liquidateLoan(uint256 loanId) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());

        hevm.prank(user);
        size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));

        __after();
    }

    function selfLiquidateLoan(uint256 loanId) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());

        hevm.prank(user);
        size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));

        __after();
    }

    function liquidateLoanWithReplacement(uint256 loanId, address borrower) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());
        borrower = _getRandomUser(borrower);

        hevm.prank(user);
        size.liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: borrower}));

        __after();
    }

    function moveToVariablePool(uint256 loanId) public getUser {
        __before();

        loanId = between(loanId, 0, size.activeLoans());

        hevm.prank(user);
        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));

        __after();
    }

    function setPrice(uint256 price) public {
        price = between(price, priceFeed.getPrice() / 2, priceFeed.getPrice() * 2);

        priceFeed.setPrice(price);
    }
}
