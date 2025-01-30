// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationTest is BaseTest {
    function test_Authorization_setAuthorization() public {
        _setAuthorization(alice, bob, ISize.sellCreditMarket.selector, true);

        assertTrue(size.isAuthorized(alice, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(alice, alice, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(alice, candy, ISize.sellCreditMarket.selector));

        assertTrue(!size.isAuthorized(bob, alice, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(bob, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(bob, candy, ISize.sellCreditMarket.selector));

        assertTrue(!size.isAuthorized(candy, alice, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(candy, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(candy, candy, ISize.sellCreditMarket.selector));
    }

    function test_Authorization_sellCreditMarketOnBehalfOf() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        _setAuthorization(bob, candy, ISize.sellCreditMarket.selector, true);

        Vars memory _before = _state();

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        uint256 debtPositionId = _sellCreditMarketOnBehalfOf(candy, bob, alice, RESERVED_ID, amount, tenor, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 issuanceValue = Math.mulDivDown(futureValue, PERCENT, PERCENT + 0.03e18);
        uint256 swapFee = size.getSwapFee(issuanceValue, tenor);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance - amount - swapFee);
        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance + amount);
        assertEq(_after.variablePool.collateralTokenBalance, _before.variablePool.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, futureValue);
    }
}
