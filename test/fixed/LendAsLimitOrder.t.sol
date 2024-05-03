// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";

contract LendAsLimitOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsLimitOrder_lendAsLimitOrder_adds_loanOffer_to_orderbook() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        assertTrue(_state().alice.user.loanOffer.isNull());
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 1.01e18);
        assertTrue(!_state().alice.user.loanOffer.isNull());
    }

    function test_LendAsLimitOrder_lendAsLimitOrder_clear_limit_order() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 1_000e6);
        _deposit(bob, weth, 300e18);
        _deposit(candy, weth, 300e18);

        uint256 maxDueDate = block.timestamp + 365 days;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 30 days;
        maturities[1] = 60 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 0.15e18;
        aprs[0] = 0.12e18;

        vm.prank(alice);
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: aprs
                })
            })
        );

        vm.prank(bob);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: 45 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: new uint256[](0)
            })
        );
        LendAsLimitOrderParams memory empty;

        vm.prank(alice);
        size.lendAsLimitOrder(empty);

        vm.expectRevert();
        vm.prank(candy);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e6,
                dueDate: 45 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: new uint256[](0)
            })
        );
    }

    function test_LendAsLimitOrder_lendAsLimitOrder_experiment_strategy_speculator() public {
        // The speculator hopes to profit off of interest rate movements, by either:
        // 1. Lending at a high interest rate and exit to other lenders when interest rates drop
        // 2. Borrowing at low interest rate and exit to other borrowers when interest rates rise
        // #### Case 1: Betting on Rates Dropping
        // Lenny the Lender lends 10,000 at 6% interest for 6 months, with a face value of 10,300.
        // Two weeks after Lenny lends, the interest rate to borrow for 5.5 months is 4.5%.
        // Lenny exits to another lender, who pays 10300/(1+0.045*11/24) = 10,091 to Lenny in return for the 10300 from the borrower in 5.5 months.
        // Lenny has now made 91 over the course of 2 weeks. While only around 1%, it’s 26% annualized without compounding, and he may compound his profits by repeating this strategy.

        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("collateralTokenCap", type(uint256).max);

        _deposit(alice, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 180 days, 0.06e18);

        _deposit(bob, weth, 20_000e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 10_000e6, block.timestamp + 180 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 faceValue = size.getDebtPosition(debtPositionId).faceValue;
        assertEqApprox(faceValue, 10_300e6, 10e6);

        vm.warp(block.timestamp + 14 days);
        _deposit(candy, usdc, faceValue);
        _lendAsLimitOrder(candy, block.timestamp + 180 days - 14 days, 0.045e18);
        _borrowAsMarketOrder(
            alice,
            candy,
            faceValue,
            size.getDebtPosition(debtPositionId).dueDate,
            block.timestamp,
            type(uint256).max,
            true,
            [creditPositionId]
        );

        assertEqApprox(_state().alice.borrowATokenBalance, 10_091e6, 10e6);
        assertEq(_state().alice.debtBalance, 0);
    }
}
