// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract LiquidateLoanTest is BaseTest {
    function test_LiquidateLoan_liquidateLoan_seizes_borrower_collateral() public {
        _setPrice(100e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 amount = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = FixedPointMathLib.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 lock = FixedPointMathLib.mulDivUp(debt, size.CROpening(), priceFeed.getPrice());
        uint256 assigned = 100e18 - lock;

        assertEq(size.getAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId, false), debt);
        assertEq(size.getDebt(loanId, true), debt / 100);
        assertTrue(!size.isLiquidatable(bob));

        _setPrice(20e18);

        assertEq(size.getAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId, false), debt);
        assertEq(size.getDebt(loanId, true), debt / 20);
        assertTrue(size.isLiquidatable(bob));

        Vars memory _before = _getUsers();

        _liquidateLoan(liquidator, loanId);

        uint256 collateralRemainder = assigned - (debt / 20);

        Vars memory _after = _getUsers();

        assertEq(_after.liquidator.cash.free, _before.liquidator.cash.free - debt);
        assertEq(_after.protocol.cash.free, _before.protocol.cash.free + debt);
        assertEq(
            _after.protocol.eth.free,
            _before.protocol.eth.free + collateralRemainder * size.collateralPercentagePremiumToProtocol() / PERCENT
        );
        assertEq(
            _after.bob.eth.free,
            _before.bob.eth.free - debt / 20
                - collateralRemainder
                    * (size.collateralPercentagePremiumToProtocol() + size.collateralPercentagePremiumToLiquidator()) / PERCENT,
            _before.bob.eth.free - debt / 20 - collateralRemainder
                + collateralRemainder * size.collateralPercentagePremiumToBorrower() / PERCENT
        );
        assertEq(
            _after.liquidator.eth.free,
            _before.liquidator.eth.free + debt / 20
                + collateralRemainder * size.collateralPercentagePremiumToLiquidator() / PERCENT
        );
    }
}
