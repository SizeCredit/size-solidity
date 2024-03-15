// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Helper} from "./Helper.sol";
import {Properties} from "./Properties.sol";
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import "@crytic/properties/contracts/util/Hevm.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Deploy} from "@script/Deploy.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";

import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START} from "@src/libraries/fixed/LoanLibrary.sol";

abstract contract TargetFunctions is Deploy, Helper, Properties, BaseTargetFunctions {
    function setup() internal override {
        setup(address(this), address(this));
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
        size.deposit(DepositParams({token: token, amount: amount, to: sender, variable: false}));

        __after();

        if (token == address(weth)) {
            eq(
                _after.sender.collateralTokenBalanceFixed,
                _before.sender.collateralTokenBalanceFixed + amount,
                DEPOSIT_01
            );
            eq(_after.senderCollateralAmount, _before.senderCollateralAmount - amount, DEPOSIT_01);
        } else {
            eq(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed + amount, DEPOSIT_01);
            eq(_after.senderBorrowAmount, _before.senderBorrowAmount - amount, DEPOSIT_01);
        }
    }

    function withdraw(address token, uint256 amount) public getSender {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);

        __before();

        uint256 maxAmount = token == address(weth) ? MAX_AMOUNT_WETH : MAX_AMOUNT_USDC;
        amount = between(amount, 0, maxAmount);
        hevm.prank(sender);
        size.withdraw(WithdrawParams({token: token, amount: amount, to: sender, variable: false}));

        __after();

        if (token == address(weth)) {
            eq(
                _after.sender.collateralTokenBalanceFixed,
                _before.sender.collateralTokenBalanceFixed - amount,
                WITHDRAW_01
            );
            eq(_after.senderCollateralAmount, _before.senderCollateralAmount + amount, WITHDRAW_01);
        } else {
            eq(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed - amount, WITHDRAW_01);
            eq(_after.senderBorrowAmount, _before.senderBorrowAmount + amount, WITHDRAW_01);
        }
    }

    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256 n,
        uint256 seedReceivableCreditPositionIds
    ) public getSender {
        __before();

        lender = _getRandomUser(lender);
        amount = between(amount, 0, MAX_AMOUNT_USDC / 100);
        dueDate = between(dueDate, block.timestamp, block.timestamp + MAX_DURATION);

        uint256[] memory receivableCreditPositionIds;
        if (_before.creditPositionsCount > 0) {
            n = between(n, 0, _before.creditPositionsCount);
            receivableCreditPositionIds = _getRandomReceivableCreditPositionIds(n, seedReceivableCreditPositionIds);
        }

        hevm.prank(sender);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        );

        __after();

        if (amount > size.riskConfig().minimumCreditBorrowAToken) {
            if (lender == sender) {
                lte(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, BORROW_03);
            } else {
                gt(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, BORROW_01);
            }

            if (receivableCreditPositionIds.length > 0) {
                gte(_after.creditPositionsCount, _before.creditPositionsCount + 1, BORROW_02);
            } else {
                eq(_after.debtPositionsCount, _before.debtPositionsCount + 1, BORROW_02);
            }
        }
    }

    function borrowAsLimitOrder(uint256 maxAmount, uint256 yieldCurveSeed) public getSender {
        __before();

        maxAmount = between(maxAmount, 0, MAX_AMOUNT_USDC);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({openingLimitBorrowCR: 0, curveRelativeTime: curveRelativeTime})
        );

        __after();
    }

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount, bool exactAmountIn)
        public
        getSender
    {
        __before();

        borrower = _getRandomUser(borrower);
        dueDate = between(dueDate, block.timestamp, block.timestamp + MAX_DURATION);
        amount = between(amount, 0, _before.sender.borrowATokenBalanceFixed / 10);

        hevm.prank(sender);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: borrower,
                dueDate: dueDate,
                amount: amount,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        __after();

        if (sender == borrower) {
            eq(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, BORROW_03);
        } else {
            lt(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, BORROW_01);
        }
        eq(_after.debtPositionsCount, _before.debtPositionsCount + 1, BORROW_02);
    }

    function lendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, uint256 yieldCurveSeed) public getSender {
        __before();

        maxAmount =
            between(maxAmount, _before.sender.borrowATokenBalanceFixed / 2, _before.sender.borrowATokenBalanceFixed);
        maxDueDate = between(maxDueDate, block.timestamp, block.timestamp + MAX_DURATION);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        size.lendAsLimitOrder(LendAsLimitOrderParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime}));

        __after();
    }

    function borrowerExit(uint256 debtPositionId, address borrowerToExitTo) public getSender {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        borrowerToExitTo = _getRandomUser(borrowerToExitTo);

        hevm.prank(sender);
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                minAPR: 0,
                deadline: block.timestamp,
                borrowerToExitTo: borrowerToExitTo
            })
        );

        __after(debtPositionId);

        if (borrowerToExitTo == sender) {
            eq(_after.sender.debtBalanceFixed, _before.sender.debtBalanceFixed, BORROWER_EXIT_01);
        } else {
            lt(_after.sender.debtBalanceFixed, _before.sender.debtBalanceFixed, BORROWER_EXIT_01);
        }
    }

    function repay(uint256 debtPositionId) public getSender {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        hevm.prank(sender);
        size.repay(RepayParams({debtPositionId: debtPositionId}));

        __after(debtPositionId);

        lte(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, REPAY_01);
        gte(_after.variablePoolBorrowAmount, _before.variablePoolBorrowAmount, REPAY_01);
        lt(_after.sender.debtBalanceFixed, _before.sender.debtBalanceFixed, REPAY_02);
    }

    function claim(uint256 creditPositionId) public getSender {
        __before(creditPositionId);

        precondition(_before.creditPositionsCount > 0);
        creditPositionId = between(creditPositionId, CREDIT_POSITION_ID_START, _before.creditPositionsCount - 1);

        hevm.prank(sender);
        size.claim(ClaimParams({creditPositionId: creditPositionId}));

        __after(creditPositionId);

        gte(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, BORROW_01);
        t(size.isCreditPositionId(creditPositionId), CLAIM_02);
    }

    function liquidate(uint256 debtPositionId, uint256 minimumCollateralProfit) public getSender {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        minimumCollateralProfit = between(minimumCollateralProfit, 0, MAX_AMOUNT_WETH);

        hevm.prank(sender);
        uint256 liquidatorProfitCollateralToken = size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );

        __after(debtPositionId);

        if (sender != _before.borrower.account) {
            gte(
                _after.sender.collateralTokenBalanceFixed,
                _before.sender.collateralTokenBalanceFixed + liquidatorProfitCollateralToken,
                LIQUIDATE_01
            );
        }
        if (_before.loanStatus != LoanStatus.OVERDUE) {
            lt(_after.sender.borrowATokenBalanceFixed, _before.sender.borrowATokenBalanceFixed, LIQUIDATE_02);
        }
        lt(_after.borrower.debtBalanceFixed, _before.borrower.debtBalanceFixed, LIQUIDATE_02);
        t(_before.isSenderLiquidatable || _before.loanStatus == LoanStatus.OVERDUE, LIQUIDATE_03);
    }

    function selfLiquidate(uint256 creditPositionId) internal getSender {
        __before(creditPositionId);

        precondition(_before.creditPositionsCount > 0);
        creditPositionId = between(creditPositionId, CREDIT_POSITION_ID_START, _before.creditPositionsCount - 1);

        hevm.prank(sender);
        size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));

        __after(creditPositionId);

        lt(_after.sender.collateralTokenBalanceFixed, _before.sender.collateralTokenBalanceFixed, LIQUIDATE_01);
        lt(_after.sender.debtBalanceFixed, _before.sender.debtBalanceFixed, LIQUIDATE_02);
    }

    function liquidateWithReplacement(uint256 debtPositionId, uint256 minimumCollateralProfit, address borrower)
        internal
        getSender
    {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        minimumCollateralProfit = between(minimumCollateralProfit, 0, MAX_AMOUNT_WETH);

        borrower = _getRandomUser(borrower);

        hevm.prank(sender);
        (uint256 liquidatorProfitCollateralToken,) = size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                minAPR: 0,
                deadline: block.timestamp,
                borrower: borrower,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        __after(debtPositionId);

        gte(
            _after.sender.collateralTokenBalanceFixed,
            _before.sender.collateralTokenBalanceFixed + liquidatorProfitCollateralToken,
            LIQUIDATE_01
        );
        lt(_after.borrower.debtBalanceFixed, _before.borrower.debtBalanceFixed, LIQUIDATE_02);
        eq(_after.totalDebtAmount, _before.totalDebtAmount, LIQUIDATION_02);
    }

    function compensate(uint256 creditPositionWithDebtToRepayId, uint256 creditPositionToCompensateId, uint256 amount)
        public
        getSender
    {
        __before(creditPositionWithDebtToRepayId);

        precondition(_before.debtPositionsCount > 0);
        creditPositionWithDebtToRepayId =
            between(creditPositionWithDebtToRepayId, CREDIT_POSITION_ID_START, _before.creditPositionsCount - 1);
        creditPositionToCompensateId =
            between(creditPositionToCompensateId, CREDIT_POSITION_ID_START, _before.creditPositionsCount - 1);

        hevm.prank(sender);
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: amount
            })
        );

        __after(creditPositionWithDebtToRepayId);

        lt(_after.sender.debtBalanceFixed, _before.sender.debtBalanceFixed, COMPENSATE_01);
    }

    function setPrice(uint256 price) public {
        price = between(price, MIN_PRICE, MAX_PRICE);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }
}
