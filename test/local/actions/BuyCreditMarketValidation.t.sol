// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {LoanStatus, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/market/libraries/YieldCurveLibrary.sol";
import {BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";

contract BuyCreditMarketTest is BaseTest {
    function test_BuyCreditMarket_validation() public {
        _updateConfig("fragmentationFee", 1e6);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _sellCreditLimit(alice, block.timestamp + 365 days, 0.03e18, 10 days);
        _sellCreditLimit(bob, block.timestamp + 365 days, 0.03e18, 10 days);
        _sellCreditLimit(candy, block.timestamp + 365 days, 0.03e18, 10 days);
        _sellCreditLimit(james, block.timestamp + 365 days, 0.03e18, 365 days);
        uint256 debtPositionId = _buyCreditMarket(alice, candy, RESERVED_ID, 40e6, 10 days, false);

        uint256 deadline = block.timestamp;
        uint256 amount = 50e6;
        uint256 tenor = 10 days;
        bool exactAmountIn = false;

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, liquidator));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: liquidator,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: address(0),
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 0,
                tenor: tenor,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TENOR_OUT_OF_RANGE.selector, 0, size.riskConfig().minTenor, size.riskConfig().maxTenor
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                tenor: 0,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector,
                1e6,
                size.riskConfig().minimumCreditBorrowToken
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 1e6,
                tenor: 365 days,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.stopPrank();
        vm.startPrank(james);

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: address(0),
                creditPositionId: creditPositionId,
                amount: 20e6,
                tenor: type(uint256).max,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_CREDIT.selector, 100e6, 20e6));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: creditPositionId,
                amount: 100e6,
                tenor: 4 days,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, deadline - 1));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 20e6,
                tenor: 10 days,
                deadline: deadline - 1,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
        vm.stopPrank();

        uint256 apr = size.getUserDefinedBorrowOfferAPR(james, 365 days);

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.APR_LOWER_THAN_MIN_APR.selector, apr, apr + 1));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 20e6,
                tenor: 365 days,
                deadline: deadline,
                minAPR: apr + 1,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
        vm.stopPrank();

        _sellCreditLimit(bob, block.timestamp + 365 days, 0, 365 days);
        _sellCreditLimit(candy, block.timestamp + 365 days, 0, 365 days);
        uint256 debtPositionId2 = _buyCreditMarket(alice, candy, RESERVED_ID, 10e6, 365 days, false);
        creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _repay(candy, debtPositionId2, candy);

        uint256 cr = size.collateralRatio(candy);

        vm.startPrank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, creditPositionId, LoanStatus.REPAID, cr
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: creditPositionId,
                amount: 10e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 123 days);

        _sellCreditLimit(james, block.timestamp + 30 days, 0.03e18, 120 days);
        vm.prank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector,
                block.timestamp + 120 days,
                block.timestamp + 30 days
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 10e6,
                tenor: 120 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: exactAmountIn,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }
}
