// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Helper} from "./Helper.sol";
import {Properties} from "./Properties.sol";
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import "@crytic/properties/contracts/util/Hevm.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
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

import {Errors} from "@src/libraries/Errors.sol";

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

            hevm.deal(user, MAX_AMOUNT_WETH / 3);
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
        try size.deposit(DepositParams({token: token, amount: amount, to: sender})) {
            __after();

            if (token == address(weth)) {
                eq(_after.sender.collateralTokenBalance, _before.sender.collateralTokenBalance + amount, DEPOSIT_01);
                eq(_after.senderCollateralAmount, _before.senderCollateralAmount - amount, DEPOSIT_01);
            } else {
                eq(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance + amount, DEPOSIT_01);
                eq(_after.senderBorrowAmount, _before.senderBorrowAmount - amount, DEPOSIT_01);
            }
        } catch (bytes memory err) {
            bytes4[5] memory errors = [
                IERC20Errors.ERC20InsufficientBalance.selector,
                Errors.INVALID_MSG_VALUE.selector,
                Errors.INVALID_TOKEN.selector,
                Errors.NULL_AMOUNT.selector,
                Errors.NULL_ADDRESS.selector
            ];
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function withdraw(address token, uint256 amount) public getSender {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);

        __before();

        uint256 maxAmount = token == address(weth) ? MAX_AMOUNT_WETH : MAX_AMOUNT_USDC;
        amount = between(amount, 0, maxAmount);
        hevm.prank(sender);
        try size.withdraw(WithdrawParams({token: token, amount: amount, to: sender})) {
            __after();

            if (token == address(weth)) {
                eq(_after.sender.collateralTokenBalance, _before.sender.collateralTokenBalance - amount, WITHDRAW_01);
                eq(_after.senderCollateralAmount, _before.senderCollateralAmount + amount, WITHDRAW_01);
            } else {
                eq(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance - amount, WITHDRAW_01);
                eq(_after.senderBorrowAmount, _before.senderBorrowAmount + amount, WITHDRAW_01);
            }
        } catch (bytes memory err) {
            bytes4[2] memory errors = [Errors.NULL_AMOUNT.selector, Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector];
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
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
        try size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        ) {
            __after();

            if (amount > size.riskConfig().minimumCreditBorrowAToken) {
                if (lender == sender) {
                    lte(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, BORROW_03);
                } else {
                    gt(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, BORROW_01);
                }

                if (receivableCreditPositionIds.length > 0) {
                    gte(_after.creditPositionsCount, _before.creditPositionsCount + 1, BORROW_02);
                } else {
                    eq(_after.debtPositionsCount, _before.debtPositionsCount + 1, BORROW_02);
                }
            }
        } catch (bytes memory err) {
            bytes4[10] memory errors = [
                Errors.INVALID_LOAN_OFFER.selector,
                Errors.NULL_AMOUNT.selector,
                Errors.PAST_DUE_DATE.selector,
                Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector,
                Errors.BORROWER_IS_NOT_LENDER.selector,
                Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector
            ];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function borrowAsLimitOrder(uint256 maxAmount, uint256 yieldCurveSeed) public getSender {
        __before();

        maxAmount = between(maxAmount, 0, MAX_AMOUNT_USDC);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        try size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({openingLimitBorrowCR: 0, curveRelativeTime: curveRelativeTime})
        ) {
            __after();
        } catch (bytes memory err) {
            bytes4[1] memory errors = [Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector];
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount, bool exactAmountIn)
        public
        getSender
    {
        __before();

        borrower = _getRandomUser(borrower);
        dueDate = between(dueDate, block.timestamp, block.timestamp + MAX_DURATION);
        amount = between(amount, 0, _before.sender.borrowATokenBalance / 10);

        hevm.prank(sender);
        try size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: borrower,
                dueDate: dueDate,
                amount: amount,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        ) {
            __after();

            if (sender == borrower) {
                eq(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, BORROW_03);
            } else {
                lt(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, BORROW_01);
            }
            eq(_after.debtPositionsCount, _before.debtPositionsCount + 1, BORROW_02);
        } catch (bytes memory err) {
            bytes4[5] memory errors = [
                Errors.INVALID_BORROW_OFFER.selector,
                Errors.PAST_DUE_DATE.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector
            ];
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function lendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, uint256 yieldCurveSeed) public getSender {
        __before();

        maxAmount = between(maxAmount, _before.sender.borrowATokenBalance / 2, _before.sender.borrowATokenBalance);
        maxDueDate = between(maxDueDate, block.timestamp, block.timestamp + MAX_DURATION);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        try size.lendAsLimitOrder(
            LendAsLimitOrderParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime})
        ) {
            __after();
        } catch (bytes memory err) {
            bytes4[2] memory errors =
                [Errors.PAST_MAX_DUE_DATE.selector, Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector];
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function borrowerExit(uint256 debtPositionId, address borrowerToExitTo) public getSender {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        borrowerToExitTo = _getRandomUser(borrowerToExitTo);

        hevm.prank(sender);
        try size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                minAPR: 0,
                deadline: block.timestamp,
                borrowerToExitTo: borrowerToExitTo
            })
        ) {
            __after(debtPositionId);

            if (borrowerToExitTo != sender) {
                lt(_after.sender.debtBalance, _before.sender.debtBalance, BORROWER_EXIT_01);
            }
        } catch (bytes memory err) {
            bytes4[5] memory errors = [
                Errors.PAST_DUE_DATE.selector,
                Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector,
                Errors.EXITER_IS_NOT_BORROWER.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector
            ];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function repay(uint256 debtPositionId) public getSender {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        hevm.prank(sender);
        try size.repay(RepayParams({debtPositionId: debtPositionId})) {
            __after(debtPositionId);

            lte(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, REPAY_01);
            gte(_after.variablePoolBorrowAmount, _before.variablePoolBorrowAmount, REPAY_01);
            lt(_after.sender.debtBalance, _before.sender.debtBalance, REPAY_02);
        } catch (bytes memory err) {
            bytes4[3] memory errors = [
                Errors.LOAN_ALREADY_REPAID.selector,
                Errors.REPAYER_IS_NOT_BORROWER.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector
            ];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function claim(uint256 creditPositionId) public getSender {
        __before(creditPositionId);

        precondition(_before.creditPositionsCount > 0);
        creditPositionId = between(creditPositionId, CREDIT_POSITION_ID_START, _before.creditPositionsCount - 1);

        hevm.prank(sender);
        try size.claim(ClaimParams({creditPositionId: creditPositionId})) {
            __after(creditPositionId);

            gte(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, BORROW_01);
            t(size.isCreditPositionId(creditPositionId), CLAIM_02);
        } catch (bytes memory err) {
            bytes4[2] memory errors = [Errors.LOAN_NOT_REPAID.selector, Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function liquidate(uint256 debtPositionId, uint256 minimumCollateralProfit) public getSender {
        __before(debtPositionId);

        precondition(_before.debtPositionsCount > 0);
        debtPositionId = between(debtPositionId, DEBT_POSITION_ID_START, _before.debtPositionsCount - 1);

        minimumCollateralProfit = between(minimumCollateralProfit, 0, MAX_AMOUNT_WETH);

        hevm.prank(sender);
        try size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        ) returns (uint256 liquidatorProfitCollateralToken) {
            __after(debtPositionId);

            if (sender != _before.borrower.account) {
                gte(
                    _after.sender.collateralTokenBalance,
                    _before.sender.collateralTokenBalance + liquidatorProfitCollateralToken,
                    LIQUIDATE_01
                );
            }
            if (_before.loanStatus != LoanStatus.OVERDUE) {
                lt(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, LIQUIDATE_02);
            }
            lt(_after.borrower.debtBalance, _before.borrower.debtBalance, LIQUIDATE_02);
            t(_before.isSenderLiquidatable || _before.loanStatus == LoanStatus.OVERDUE, LIQUIDATE_03);
        } catch (bytes memory err) {
            bytes4[2] memory errors = [
                Errors.LOAN_NOT_LIQUIDATABLE.selector,
                Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT.selector
            ];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function selfLiquidate(uint256 creditPositionId) internal getSender {
        __before(creditPositionId);

        precondition(_before.creditPositionsCount > 0);
        creditPositionId = between(creditPositionId, CREDIT_POSITION_ID_START, _before.creditPositionsCount - 1);

        hevm.prank(sender);
        try size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId})) {
            __after(creditPositionId);

            lt(_after.sender.collateralTokenBalance, _before.sender.collateralTokenBalance, LIQUIDATE_01);
            lt(_after.sender.debtBalance, _before.sender.debtBalance, LIQUIDATE_02);
        } catch (bytes memory err) {
            bytes4[3] memory errors = [
                Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector,
                Errors.LIQUIDATION_NOT_AT_LOSS.selector,
                Errors.LIQUIDATOR_IS_NOT_LENDER.selector
            ];
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
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
        try size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                minAPR: 0,
                deadline: block.timestamp,
                borrower: borrower,
                minimumCollateralProfit: minimumCollateralProfit
            })
        ) returns (uint256 liquidatorProfitCollateralToken, uint256) {
            __after(debtPositionId);

            gte(
                _after.sender.collateralTokenBalance,
                _before.sender.collateralTokenBalance + liquidatorProfitCollateralToken,
                LIQUIDATE_01
            );
            lt(_after.borrower.debtBalance, _before.borrower.debtBalance, LIQUIDATE_02);
            eq(_after.totalDebtAmount, _before.totalDebtAmount, LIQUIDATION_02);
        } catch (bytes memory err) {
            bytes4[3] memory errors = [
                Errors.LOAN_NOT_ACTIVE.selector,
                Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector,
                Errors.INVALID_BORROW_OFFER.selector
            ];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
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
        try size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: amount
            })
        ) {
            __after(creditPositionWithDebtToRepayId);

            lt(_after.sender.debtBalance, _before.sender.debtBalance, COMPENSATE_01);
        } catch (bytes memory err) {
            bytes4[9] memory errors = [
                Errors.LOAN_ALREADY_REPAID.selector,
                Errors.CREDIT_LOWER_THAN_AMOUNT_TO_COMPENSATE.selector,
                Errors.LOAN_ALREADY_REPAID.selector,
                Errors.DUE_DATE_NOT_COMPATIBLE.selector,
                Errors.INVALID_LENDER.selector,
                Errors.COMPENSATOR_IS_NOT_BORROWER.selector,
                Errors.NULL_AMOUNT.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector
            ];

            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(err)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function setPrice(uint256 price) public {
        price = between(price, MIN_PRICE, MAX_PRICE);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }
}
