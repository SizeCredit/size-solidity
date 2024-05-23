// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {PERCENT} from "@src/libraries/Math.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {Vars} from "@test/BaseTestGeneral.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyCreditMarketTest is BaseTest {
    // function test_BuyCreditMarket_parameter_validation() public {
    //     // try calling specifying both borrower and credit position
    //     vm.startPrank(james);
    //     vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: 3,
    //             dueDate: 0,
    //             amount: 10000,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: false
    //         })
    //     );

    //     // try calling specifying neither borrower or creditposition
    //     vm.startPrank(james);
    //     vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: address(0),
    //             creditPositionId: RESERVED_ID,
    //             dueDate: 0,
    //             amount: 10000,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: false
    //         })
    //     );
    // }
}
