// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Helper} from "./Helper.sol";
import {Properties} from "./Properties.sol";
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";

import "@crytic/properties/contracts/util/Hevm.sol";

import {Math, PERCENT} from "@src/libraries/Math.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {SellCreditLimitParams} from "@src/libraries/actions/SellCreditLimit.sol";
import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";

import {ClaimParams} from "@src/libraries/actions/Claim.sol";

import {CompensateParams} from "@src/libraries/actions/Compensate.sol";

import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";
import {BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LiquidateParams} from "@src/libraries/actions/Liquidate.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/actions/LiquidateWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/libraries/actions/SelfLiquidate.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {SetUserConfigurationParams} from "@src/libraries/actions/SetUserConfiguration.sol";

import {UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {KEEPER_ROLE} from "@src/Size.sol";

import {ExpectedErrors} from "@test/invariants/ExpectedErrors.sol";
import {ITargetFunctions} from "@test/invariants/interfaces/ITargetFunctions.sol";

import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

abstract contract TargetFunctions is Helper, ExpectedErrors, BaseTargetFunctions, ITargetFunctions {
    function setup() internal override {
        setupLocal(address(this), address(this));
        size.grantRole(KEEPER_ROLE, USER2);

        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        usdc.mint(address(this), MAX_AMOUNT_USDC);
        hevm.deal(address(this), MAX_AMOUNT_WETH);
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            usdc.mint(user, MAX_AMOUNT_USDC);

            hevm.deal(address(this), MAX_AMOUNT_WETH);
            weth.deposit{value: MAX_AMOUNT_WETH}();
            weth.transfer(user, MAX_AMOUNT_WETH);
        }
    }

    function deposit(address token, uint256 amount) public getSender checkExpectedErrors(DEPOSIT_ERRORS) {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);
        amount = between(amount, 0, token == address(weth) ? MAX_AMOUNT_WETH : MAX_AMOUNT_USDC);

        __before();

        hevm.prank(sender);
        IERC20Metadata(token).approve(address(size), amount);

        hevm.prank(sender);
        (success, returnData) =
            address(size).call(abi.encodeCall(size.deposit, DepositParams({token: token, amount: amount, to: sender})));
        if (success) {
            __after();

            if (token == address(weth)) {
                eq(_after.sender.collateralTokenBalance, _before.sender.collateralTokenBalance + amount, DEPOSIT_01);
                eq(_after.senderCollateralAmount, _before.senderCollateralAmount - amount, DEPOSIT_01);
                eq(_after.sizeCollateralAmount, _before.sizeCollateralAmount + amount, DEPOSIT_02);
            } else {
                if (variablePool.getReserveNormalizedIncome(address(usdc)) == WadRayMath.RAY) {
                    eq(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance + amount, DEPOSIT_01);
                }
                eq(_after.senderBorrowAmount, _before.senderBorrowAmount - amount, DEPOSIT_01);
                eq(_after.sizeBorrowAmount, _before.sizeBorrowAmount + amount, DEPOSIT_02);
            }
        }
    }

    function withdraw(address token, uint256 amount) public getSender checkExpectedErrors(WITHDRAW_ERRORS) {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);

        __before();

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(size.withdraw, WithdrawParams({token: token, amount: amount, to: sender}))
        );
        if (success) {
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
                eq(_after.sizeCollateralAmount, _before.sizeCollateralAmount - withdrawnAmount, WITHDRAW_02);
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
                eq(_after.sizeBorrowAmount, _before.sizeBorrowAmount - withdrawnAmount, WITHDRAW_01);
            }
        }
    }

    function sellCreditMarket(
        address lender,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        bool exactAmountIn
    ) public getSender checkExpectedErrors(SELL_CREDIT_MARKET_ERRORS) {
        __before();

        lender = _getRandomUser(lender);
        creditPositionId = _getCreditPositionId(creditPositionId);
        amount = between(amount, 0, MAX_AMOUNT_USDC);
        tenor = between(tenor, 0, MAX_DURATION);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.sellCreditMarket,
                SellCreditMarketParams({
                    lender: lender,
                    creditPositionId: creditPositionId,
                    amount: amount,
                    tenor: tenor,
                    deadline: block.timestamp,
                    maxAPR: type(uint256).max,
                    exactAmountIn: exactAmountIn
                })
            )
        );

        if (success) {
            __after();

            if (lender != sender) {
                gt(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, BORROW_01);
            }

            if (creditPositionId == RESERVED_ID) {
                eq(_after.debtPositionsCount, _before.debtPositionsCount + 1, BORROW_02);
                uint256 debtPositionId = DEBT_POSITION_ID_START + _after.debtPositionsCount - 1;
                tenor = size.getDebtPosition(debtPositionId).dueDate - block.timestamp;
                t(size.riskConfig().minTenor <= tenor && tenor <= size.riskConfig().maxTenor, LOAN_01);
            }
        }
    }

    function sellCreditLimit(uint256 yieldCurveSeed) public getSender checkExpectedErrors(SELL_CREDIT_LIMIT_ERRORS) {
        __before();

        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(size.sellCreditLimit, SellCreditLimitParams({curveRelativeTime: curveRelativeTime}))
        );
        if (success) {
            __after();
        }
    }

    function buyCreditMarket(
        address borrower,
        uint256 creditPositionId,
        uint256 tenor,
        uint256 amount,
        bool exactAmountIn
    ) public getSender checkExpectedErrors(BUY_CREDIT_MARKET_ERRORS) {
        __before();

        borrower = _getRandomUser(borrower);
        creditPositionId = _getCreditPositionId(creditPositionId);
        tenor = between(tenor, 0, MAX_DURATION);
        amount = between(amount, 0, MAX_AMOUNT_USDC);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.buyCreditMarket,
                BuyCreditMarketParams({
                    borrower: borrower,
                    creditPositionId: creditPositionId,
                    tenor: tenor,
                    amount: amount,
                    deadline: block.timestamp,
                    minAPR: 0,
                    exactAmountIn: exactAmountIn
                })
            )
        );
        if (success) {
            __after();

            if (creditPositionId == RESERVED_ID) {
                eq(_after.debtPositionsCount, _before.debtPositionsCount + 1, BORROW_02);
                uint256 debtPositionId = DEBT_POSITION_ID_START + _after.debtPositionsCount - 1;
                tenor = size.getDebtPosition(debtPositionId).dueDate - block.timestamp;
                t(size.riskConfig().minTenor <= tenor && tenor <= size.riskConfig().maxTenor, LOAN_01);
            }
        }
    }

    function buyCreditLimit(uint256 maxDueDate, uint256 yieldCurveSeed)
        public
        getSender
        checkExpectedErrors(BUY_CREDIT_LIMIT_ERRORS)
    {
        __before();

        maxDueDate = between(maxDueDate, block.timestamp, block.timestamp + MAX_DURATION);
        YieldCurve memory curveRelativeTime = _getRandomYieldCurve(yieldCurveSeed);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.buyCreditLimit,
                BuyCreditLimitParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime})
            )
        );
        if (success) {
            __after();
        }
    }

    function repay(uint256 debtPositionId) public getSender hasLoans checkExpectedErrors(REPAY_ERRORS) {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

        hevm.prank(sender);
        (success, returnData) =
            address(size).call(abi.encodeCall(size.repay, RepayParams({debtPositionId: debtPositionId})));
        if (success) {
            __after(debtPositionId);

            lte(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, REPAY_01);
            gte(_after.variablePoolBorrowAmount, _before.variablePoolBorrowAmount, REPAY_01);
            lt(_after.borrower.debtBalance, _before.borrower.debtBalance, REPAY_02);
            eq(uint256(_after.loanStatus), uint256(LoanStatus.REPAID), REPAY_03);
        }
    }

    function claim(uint256 creditPositionId) public getSender hasLoans checkExpectedErrors(CLAIM_ERRORS) {
        creditPositionId = between(
            creditPositionId, CREDIT_POSITION_ID_START, CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );
        __before(creditPositionId);

        hevm.prank(sender);
        (success, returnData) =
            address(size).call(abi.encodeCall(size.claim, ClaimParams({creditPositionId: creditPositionId})));
        if (success) {
            __after(creditPositionId);

            gte(_after.sender.borrowATokenBalance, _before.sender.borrowATokenBalance, CLAIM_01);
            t(size.isCreditPositionId(creditPositionId), CLAIM_02);
        }
    }

    function liquidate(uint256 debtPositionId, uint256 minimumCollateralProfit)
        public
        getSender
        hasLoans
        checkExpectedErrors(LIQUIDATE_ERRORS)
    {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

        minimumCollateralProfit = between(minimumCollateralProfit, 0, MAX_AMOUNT_WETH);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.liquidate,
                LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
            )
        );
        if (success) {
            __after(debtPositionId);

            uint256 liquidatorProfitCollateralToken = abi.decode(returnData, (uint256));

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
            t(_before.isBorrowerUnderwater || _before.loanStatus == LoanStatus.OVERDUE, LIQUIDATE_03);
            eq(uint256(_after.loanStatus), uint256(LoanStatus.REPAID), LIQUIDATE_05);
        }
    }

    function selfLiquidate(uint256 creditPositionId)
        public
        getSender
        hasLoans
        checkExpectedErrors(SELF_LIQUIDATE_ERRORS)
    {
        creditPositionId = between(
            creditPositionId, CREDIT_POSITION_ID_START, CREDIT_POSITION_ID_START + _before.creditPositionsCount - 1
        );
        __before(creditPositionId);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(size.selfLiquidate, SelfLiquidateParams({creditPositionId: creditPositionId}))
        );
        if (success) {
            __after(creditPositionId);

            if (sender != _before.borrower.account) {
                gte(_after.sender.collateralTokenBalance, _before.sender.collateralTokenBalance, SELF_LIQUIDATE_01);
            }
            lte(_after.borrower.debtBalance, _before.borrower.debtBalance, SELF_LIQUIDATE_02);
        }
    }

    function liquidateWithReplacement(uint256 debtPositionId, uint256 minimumCollateralProfit, address borrower)
        public
        getSender
        hasLoans
        checkExpectedErrors(LIQUIDATE_WITH_REPLACEMENT_ERRORS)
    {
        debtPositionId =
            between(debtPositionId, DEBT_POSITION_ID_START, DEBT_POSITION_ID_START + _before.debtPositionsCount - 1);
        __before(debtPositionId);

        minimumCollateralProfit = between(minimumCollateralProfit, 0, MAX_AMOUNT_WETH);

        borrower = _getRandomUser(borrower);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.liquidateWithReplacement,
                LiquidateWithReplacementParams({
                    debtPositionId: debtPositionId,
                    minAPR: 0,
                    deadline: block.timestamp,
                    borrower: borrower,
                    minimumCollateralProfit: minimumCollateralProfit
                })
            )
        );
        if (success) {
            __after(debtPositionId);
            (uint256 liquidatorProfitCollateralToken,) = abi.decode(returnData, (uint256, uint256));

            gte(
                _after.sender.collateralTokenBalance,
                _before.sender.collateralTokenBalance + liquidatorProfitCollateralToken,
                LIQUIDATE_01
            );
            lt(_after.borrower.debtBalance, _before.borrower.debtBalance, LIQUIDATE_02);
            uint256 tenor = size.getDebtPosition(debtPositionId).dueDate - block.timestamp;
            t(size.riskConfig().minTenor <= tenor && tenor <= size.riskConfig().maxTenor, LOAN_01);
        }
    }

    function compensate(uint256 creditPositionWithDebtToRepayId, uint256 creditPositionToCompensateId, uint256 amount)
        public
        getSender
        hasLoans
        checkExpectedErrors(COMPENSATE_ERRORS)
    {
        creditPositionWithDebtToRepayId = _getCreditPositionId(creditPositionWithDebtToRepayId);
        creditPositionToCompensateId = _getCreditPositionId(creditPositionToCompensateId);

        __before(creditPositionWithDebtToRepayId);

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.compensate,
                CompensateParams({
                    creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                    creditPositionToCompensateId: creditPositionToCompensateId,
                    amount: amount
                })
            )
        );
        if (success) {
            __after(creditPositionWithDebtToRepayId);

            if (creditPositionToCompensateId == RESERVED_ID) {
                eq(_after.borrower.debtBalance, _before.borrower.debtBalance, COMPENSATE_01);
            } else {
                lt(_after.borrower.debtBalance, _before.borrower.debtBalance, COMPENSATE_02);
            }
        }
    }

    function setUserConfiguration(uint256 openingLimitBorrowCR, bool allCreditPositionsForSaleDisabled)
        public
        getSender
        checkExpectedErrors(SET_USER_CONFIGURATION_ERRORS)
    {
        __before();

        hevm.prank(sender);
        (success, returnData) = address(size).call(
            abi.encodeCall(
                size.setUserConfiguration,
                SetUserConfigurationParams({
                    openingLimitBorrowCR: openingLimitBorrowCR,
                    allCreditPositionsForSaleDisabled: allCreditPositionsForSaleDisabled,
                    creditPositionIdsForSale: false,
                    creditPositionIds: new uint256[](0)
                })
            )
        );
        if (success) {
            __after();
        }
    }

    function setPrice(uint256 price) public clear {
        price = between(price, MIN_PRICE, MAX_PRICE);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function setLiquidityIndex(uint256 liquidityIndex, uint256 supplyAmount) public clear {
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

    function updateConfig(uint256 i, uint256 value) public clear {
        string[12] memory keys = [
            "crOpening",
            "crLiquidation",
            "minimumCreditBorrowAToken",
            "borrowATokenCap",
            "minTenor",
            "maxTenor",
            "swapFeeAPR",
            "fragmentationFee",
            "liquidationRewardPercent",
            "overdueCollateralProtocolPercent",
            "collateralProtocolPercent",
            "variablePoolBorrowRateStaleRateInterval"
        ];
        uint256[12] memory maxValues = [
            MAX_PERCENT,
            MAX_PERCENT,
            MAX_AMOUNT_USDC,
            MAX_AMOUNT_USDC,
            MAX_DURATION,
            MAX_DURATION,
            MAX_PERCENT,
            MAX_AMOUNT_USDC,
            MAX_PERCENT,
            MAX_PERCENT,
            MAX_PERCENT,
            MAX_DURATION
        ];
        i = between(i, 0, keys.length - 1);
        string memory key = keys[i];
        value = between(value, 0, maxValues[i]);
        size.updateConfig(UpdateConfigParams({key: key, value: value}));

        uint128 borrowRate = uint128(between(value, 0, MAX_PERCENT));
        size.setVariablePoolBorrowRate(borrowRate);
    }
}
