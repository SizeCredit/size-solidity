// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {DebtPosition} from "@src/libraries/LoanLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

contract SellCreditLimitTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_SellCreditLimit_sellCreditLimit_adds_borrowOffer_to_orderbook() public {
        _deposit(alice, weth, 100e18);
        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 1.01e18;
        aprs[1] = 1.02e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _sellCreditLimit(alice, YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers}));

        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }

    function testFuzz_SellCreditLimit_sellCreditLimit_adds_borrowOffer_to_orderbook(uint256 buckets, bytes32 seed)
        public
    {
        buckets = bound(buckets, 1, 365);
        uint256[] memory tenors = new uint256[](buckets);
        int256[] memory aprs = new int256[](buckets);
        uint256[] memory marketRateMultipliers = new uint256[](buckets);

        for (uint256 i = 0; i < buckets; i++) {
            tenors[i] = (i + 1) * 1 days;
            aprs[i] = int256(bound(uint256(keccak256(abi.encode(seed, i))), 0, 10e18));
        }
        _sellCreditLimit(alice, YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers}));
    }

    function test_SellCreditLimit_sellCreditLimit_cant_be_placed_if_cr_is_below_openingLimitBorrowCR() public {
        _setPrice(1e18);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 150e18);
        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 0e18;
        aprs[1] = 1e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        _setUserConfiguration(alice, 1.7e18, false, false, new uint256[](0));
        _sellCreditLimit(alice, YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers}));

        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.5e18, 1.7e18));
        vm.prank(bob);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                tenor: 1 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );
    }

    function test_SellCreditLimit_sellCreditLimit_cant_be_placed_if_cr_is_below_crOpening_even_if_openingLimitBorrowCR_is_below(
    ) public {
        _setPrice(1e18);
        _deposit(bob, usdc, 100e6);
        _deposit(alice, weth, 140e18);
        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 0e18;
        aprs[1] = 1e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        _setUserConfiguration(alice, 1.3e18, false, false, new uint256[](0));
        _sellCreditLimit(alice, YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers}));
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.4e18, 1.5e18));
        vm.prank(bob);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                tenor: 1 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );
    }

    function test_SellCreditLimit_sellCreditLimit_experiment_strategy_speculator() public {
        // #### Case 2: Betting on Rates Increasing
        // Bobby the borrower creates a limit offer to borrow at 2%, which gets filled by an exiting borrower for Cash=12,000, FV=12,080 USDC with a remaining term of 4 months.
        // Two weeks later, someone named Sammy offers to borrow at 3.5%
        // Bobby exits to Sammy (who is willing to pay 3.5% for the remaining 3.5 months, thus borrowing 12080/(1+0.035*7/24) = 11,958 to pay back 12,080 in 3.5 months).
        // Bobby now has a 42 USDC profit. Not huge, only 0.3%, but 9% annualized without compounding.
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(bob, weth, 20_000e18);
        _sellCreditLimit(bob, [int256(0.02e18)], [uint256(120 days)]);

        _deposit(candy, usdc, 20_000e6);
        uint256 debtPositionId = _buyCreditMarket(candy, bob, 12_000e6, 120 days, true);

        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        assertEqApprox(debtPosition.futureValue, 12_080e6, 2e6);

        vm.warp(block.timestamp + 14 days);

        _deposit(james, weth, 20_000e18);
        _sellCreditLimit(james, [int256(0.035e18)], [uint256(120 days - 14 days)]);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        uint256 debtPositionId2 =
            _buyCreditMarket(bob, james, debtPosition.futureValue, debtPosition.dueDate - block.timestamp);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(bob, creditPositionId, creditPositionId2);

        assertEqApprox(_state().bob.borrowATokenBalance, 42e6, 1e6);
        assertEq(_state().bob.debtBalance, 0);
    }
}
