// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Helper} from "./Helper.sol";
import {Properties} from "./Properties.sol";
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";

import "@crytic/properties/contracts/util/Hevm.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {Math, PERCENT} from "@src/libraries/Math.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

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

import {BuyMarketCreditParams} from "@src/libraries/fixed/actions/BuyMarketCredit.sol";
import {SetCreditForSaleParams} from "@src/libraries/fixed/actions/SetCreditForSale.sol";

import {KEEPER_ROLE} from "@src/Size.sol";

// import {console2 as console} from "forge-std/console2.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START} from "@src/libraries/fixed/LoanLibrary.sol";

abstract contract TargetFunctions is Deploy, Helper, Properties, BaseTargetFunctions {
    function setup() internal override {
        setupLocal(address(this), address(this));
        size.grantRole(KEEPER_ROLE, USER2);

        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        usdc.mint(address(this), MAX_AMOUNT_USDC);
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            usdc.mint(user, MAX_AMOUNT_USDC / 3);

            hevm.deal(address(this), MAX_AMOUNT_WETH / 3);
            weth.deposit{value: MAX_AMOUNT_WETH / 3}();
            weth.transfer(user, MAX_AMOUNT_WETH / 3);
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
                if (variablePool.getReserveNormalizedIncome(address(usdc)) == WadRayMath.RAY) {
                    eq(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance + amount, DEPOSIT_01);
                }
                eq(_after.senderBorrowAmount, _before.senderBorrowAmount - amount, DEPOSIT_01);
            }
        } catch (bytes memory err) {
            bytes4[4] memory errors = [
                IERC20Errors.ERC20InsufficientBalance.selector,
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
            uint256 withdrawnAmount;

            if (token == address(weth)) {
                withdrawnAmount = Math.min(amount, _before.sender.collateralTokenBalance);
                eq(
                    _after.sender.collateralTokenBalance,
                    _before.sender.collateralTokenBalance - withdrawnAmount,
                    WITHDRAW_01
                );
                eq(_after.senderCollateralAmount, _before.senderCollateralAmount + withdrawnAmount, WITHDRAW_01);
            } else {
                withdrawnAmount = Math.min(amount, _before.sender.borrowATokenBalance);
                if (variablePool.getReserveNormalizedIncome(address(usdc)) == WadRayMath.RAY) {
                    eq(
                        _after.sender.borrowATokenBalance,
                        _before.sender.borrowATokenBalance - withdrawnAmount,
                        WITHDRAW_01
                    );
                }
                eq(_after.senderBorrowAmount, _before.senderBorrowAmount + withdrawnAmount, WITHDRAW_01);
            }
        } catch (bytes memory err) {
            bytes4[3] memory errors = [
                Errors.NULL_AMOUNT.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                IERC20Errors.ERC20InsufficientBalance.selector
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
        } catch (bytes memory err) {
            bytes4[12] memory errors = [
                Errors.INVALID_LOAN_OFFER.selector,
                Errors.NULL_AMOUNT.selector,
                Errors.PAST_DUE_DATE.selector,
                Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector,
                Errors.BORROWER_IS_NOT_LENDER.selector,
                Errors.DUE_DATE_LOWER_THAN_DEBT_POSITION_DUE_DATE.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector
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
            bytes4[7] memory errors = [
                Errors.INVALID_BORROW_OFFER.selector,
                Errors.PAST_DUE_DATE.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector
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

    function borrowerExit(uint256 debtPositionId, address borrowerToExitTo) public getSender hasLoans {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

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
            bytes4[9] memory errors = [
                Errors.PAST_DUE_DATE.selector,
                Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector,
                Errors.EXITER_IS_NOT_BORROWER.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector,
                Errors.INVALID_BORROW_OFFER.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector,
                Errors.LOAN_NOT_ACTIVE.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector
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

    function repay(uint256 debtPositionId) public getSender hasLoans {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

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

    function claim(uint256 creditPositionId) public getSender hasLoans {
        creditPositionId = between(
            creditPositionId, CREDIT_POSITION_ID_START, CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );
        __before(creditPositionId);

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

    function liquidate(uint256 debtPositionId, uint256 minimumCollateralProfit) public getSender hasLoans {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

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
            t(_before.isBorrowerLiquidatable || _before.loanStatus == LoanStatus.OVERDUE, LIQUIDATE_03);
        } catch (bytes memory err) {
            bytes4[3] memory errors = [
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector,
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

    function selfLiquidate(uint256 creditPositionId) public getSender hasLoans {
        creditPositionId = between(
            creditPositionId, CREDIT_POSITION_ID_START, CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );
        __before(creditPositionId);

        hevm.prank(sender);
        try size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId})) {
            __after(creditPositionId);

            if (sender != _before.borrower.account) {
                gte(_after.sender.collateralTokenBalance, _before.sender.collateralTokenBalance, SELF_LIQUIDATE_01);
            }
            lte(_after.borrower.debtBalance, _before.borrower.debtBalance, SELF_LIQUIDATE_02);
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
        public
        getSender
        hasLoans
    {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

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
            bytes4[7] memory errors = [
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector,
                Errors.LOAN_NOT_LIQUIDATABLE.selector,
                Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT.selector,
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
        hasLoans
    {
        creditPositionWithDebtToRepayId = between(
            creditPositionWithDebtToRepayId,
            CREDIT_POSITION_ID_START,
            CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );
        creditPositionToCompensateId = between(
            creditPositionToCompensateId,
            CREDIT_POSITION_ID_START,
            CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );

        __before(creditPositionWithDebtToRepayId);

        hevm.prank(sender);
        try size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: amount
            })
        ) {
            __after(creditPositionWithDebtToRepayId);

            lt(_after.borrower.debtBalance, _before.borrower.debtBalance, COMPENSATE_01);
        } catch (bytes memory err) {
            bytes4[11] memory errors = [
                Errors.LOAN_ALREADY_REPAID.selector,
                Errors.CREDIT_LOWER_THAN_AMOUNT_TO_COMPENSATE.selector,
                Errors.LOAN_ALREADY_REPAID.selector,
                Errors.DUE_DATE_NOT_COMPATIBLE.selector,
                Errors.INVALID_LENDER.selector,
                Errors.COMPENSATOR_IS_NOT_BORROWER.selector,
                Errors.NULL_AMOUNT.selector,
                Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector,
                Errors.INVALID_CREDIT_POSITION_ID.selector
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

    function buyMarketCredit(uint256 creditPositionId, uint256 amount, bool exactAmountIn) public getSender hasLoans {
        creditPositionId = between(
            creditPositionId, CREDIT_POSITION_ID_START, CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );
        __before(creditPositionId);

        amount = between(amount, 0, MAX_AMOUNT_USDC);

        hevm.prank(sender);
        try size.buyMarketCredit(
            BuyMarketCreditParams({
                creditPositionId: creditPositionId,
                amount: amount,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        ) {
            __after(creditPositionId);
        } catch (bytes memory err) {
            bytes4[9] memory errors = [
                Errors.LOAN_NOT_ACTIVE.selector,
                Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector,
                Errors.NULL_OFFER.selector,
                Errors.CREDIT_NOT_FOR_SALE.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector,
                Errors.MATURITY_OUT_OF_RANGE.selector,
                Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector,
                Errors.NOT_ENOUGH_CREDIT.selector
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

    function setCreditForSale(bool creditPositionsForSaleDisabled) public {
        __before();

        hevm.prank(sender);
        try size.setCreditForSale(
            SetCreditForSaleParams({
                creditPositionsForSaleDisabled: creditPositionsForSaleDisabled,
                forSale: creditPositionsForSaleDisabled,
                creditPositionIds: new uint256[](0)
            })
        ) {
            __after();
        } catch {
            t(false, DOS);
        }
    }

    function setPrice(uint256 price) public {
        price = between(price, MIN_PRICE, MAX_PRICE);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function setLiquidityIndex(uint256 liquidityIndex, uint256 supplyAmount) public {
        uint256 currentLiquidityIndex = variablePool.getReserveNormalizedIncome(address(usdc));
        liquidityIndex =
            (between(liquidityIndex, PERCENT, MAX_LIQUIDITY_INDEX_INCREASE_PERCENT)) * currentLiquidityIndex / PERCENT;
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), liquidityIndex);

        supplyAmount = between(supplyAmount, 0, MAX_AMOUNT_USDC);
        if (supplyAmount > 0) {
            usdc.approve(address(variablePool), supplyAmount);
            variablePool.supply(address(usdc), supplyAmount, address(this), 0);
        }
    }
}
