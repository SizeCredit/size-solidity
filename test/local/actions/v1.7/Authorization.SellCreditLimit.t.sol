// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/market/SizeView.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";
import {
    SellCreditLimitOnBehalfOfParams, SellCreditLimitParams
} from "@src/market/libraries/actions/SellCreditLimit.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract AuthorizationSellCreditLimitTest is BaseTest {
    using OfferLibrary for LimitOrder;

    function test_AuthorizationSellCreditLimit_sellCreditLimitOnBehalfOf() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(Action.SELL_CREDIT_LIMIT));

        _deposit(alice, weth, 100e18);
        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 1.01e18;
        aprs[1] = 1.02e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        assertTrue(_state().alice.user.borrowOffer.isNull());

        vm.prank(bob);
        size.sellCreditLimitOnBehalfOf(
            SellCreditLimitOnBehalfOfParams({
                params: SellCreditLimitParams({
                    maxDueDate: block.timestamp + 365 days,
                    curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
                }),
                onBehalfOf: alice
            })
        );

        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }

    function test_AuthorizationSellCreditLimit_validation() public {
        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 2 days;
        int256[] memory aprs = new int256[](2);
        aprs[0] = 1.01e18;
        aprs[1] = 1.02e18;
        uint256[] memory marketRateMultipliers = new uint256[](2);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.SELL_CREDIT_LIMIT)
        );
        vm.prank(alice);
        size.sellCreditLimitOnBehalfOf(
            SellCreditLimitOnBehalfOfParams({
                params: SellCreditLimitParams({
                    maxDueDate: block.timestamp + 365 days,
                    curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
                }),
                onBehalfOf: bob
            })
        );
    }
}
