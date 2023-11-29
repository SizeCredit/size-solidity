// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract LiquidateLoanTest is BaseTest {
    function test_LiquidateLoan_liquidateLoan_seizes_borrower_collateral() public {
        _setPrice(1e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);

        assertEq(size.getCollateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e4, 12);
        uint256 amount = 15e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = FixedPointMathLib.mulDivUp(amount, (PERCENT + 0.03e4), PERCENT);
        uint256 lock = FixedPointMathLib.mulDivUp(debt, size.CROpening(), priceFeed.getPrice());
        uint256 assigned = 100e18 - lock;

        assertEq(size.getAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId), debt);
        assertEq(size.getCollateralRatio(bob), assigned * 1e4 / (debt * 1));
        assertTrue(!size.isLiquidatable(bob));

        _setPrice(0.2e18);

        assertEq(size.getAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId), debt);
        assertEq(size.getCollateralRatio(bob), assigned * 1e4 / (debt * 5));
        assertTrue(size.isLiquidatable(bob));

        Vars memory _before = _getUsers();

        _liquidateLoan(liquidator, loanId);

        uint256 collateralRemainder = assigned - (debt * 5);

        Vars memory _after = _getUsers();

        assertEq(_after.liquidator.borrowAsset.free, _before.liquidator.borrowAsset.free - debt);
        assertEq(_after.protocol.borrowAsset.free, _before.protocol.borrowAsset.free + debt);
        assertEq(
            _after.protocol.collateralAsset.free,
            _before.protocol.collateralAsset.free
                + collateralRemainder * size.collateralPercentagePremiumToProtocol() / PERCENT
        );
        assertEq(
            _after.bob.collateralAsset.free,
            _before.bob.collateralAsset.free - (debt * 5)
                - collateralRemainder
                    * (size.collateralPercentagePremiumToProtocol() + size.collateralPercentagePremiumToLiquidator()) / PERCENT,
            _before.bob.collateralAsset.free - (debt * 5) - collateralRemainder
                + collateralRemainder * size.collateralPercentagePremiumToBorrower() / PERCENT
        );
        assertEq(
            _after.liquidator.collateralAsset.free,
            _before.liquidator.collateralAsset.free + (debt * 5)
                + collateralRemainder * size.collateralPercentagePremiumToLiquidator() / PERCENT
        );
    }
}
