// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./mocks/OrderbookMock.sol";
import "./mocks/PriceFeedMock.sol";
import "../src/libraries/UserLibrary.sol";
import "../src/libraries/RealCollateralLibrary.sol";
import "../src/libraries/OfferLibrary.sol";
import "../src/libraries/ScheduleLibrary.sol";
import "./ExperimentsHelper.sol";

contract OrderbookTest is Test, ExperimentsHelper {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    OrderbookMock public orderbook;
    PriceFeedMock public priceFeed;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new OrderbookMock()),
            abi.encodeWithSelector(
                Orderbook.initialize.selector,
                address(this),
                priceFeed,
                12,
                1.5e18,
                1.3e18
            )
        );
        orderbook = OrderbookMock(address(proxy));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");

        // starts at t=0
        vm.warp(0);
    }

    function test_experiment_1() public {
        console.log("Basic Functioning");
        console.log("Place an offer");
        console.log("Pick a loan from that offer");

        console.log("context");
        priceFeed.setPrice(100e18);

        vm.prank(alice);
        orderbook.deposit(100e18, 0);
        vm.prank(bob);
        orderbook.deposit(100e18, 0);
        vm.prank(james);
        orderbook.deposit(100e18, 0);

        console.log(
            "Let's pretend she has some virtual collateral i.e. some loan she has given"
        );
        orderbook.setExpectedFV(alice, 3, 100e18);

        vm.prank(bob);
        orderbook.place(100e18, 10, 0.03e18);

        console.log("This will revert");
        vm.prank(alice);
        vm.expectRevert();
        orderbook.pick(1, 100e18, 6);

        console.log("This will succeed");
        vm.prank(alice);
        orderbook.pick(1, 50e18, 6);

        plot("bob_1", orderbook.getBorrowerStatus(bob));
        plot("alice_1", orderbook.getBorrowerStatus(alice));
        plot("james_1", orderbook.getBorrowerStatus(james));
    }

    function test_experiment_2() public {
        console.log("Extension of the above with borrower liquidation");

        console.log("context");
        priceFeed.setPrice(100e18);

        vm.prank(alice);
        orderbook.deposit(100e18, 20e18);
        vm.prank(bob);
        orderbook.deposit(100e18, 20e18);

        vm.prank(bob);
        orderbook.place(100e18, 10, 0.03e18);

        console.log("This should work now");
        plot("alice_2_0", orderbook.getBorrowerStatus(alice));

        vm.prank(alice);
        orderbook.pick(1, 100e18, 6);

        assertEq(
            orderbook.getCollateralRatio(alice),
            orderbook.CROpening(),
            "Alice Collateral Ratio == CROpening"
        );
        assertFalse(
            orderbook.isLiquidatable(alice),
            "Borrower should not be liquidatable"
        );

        plot("alice_2_1", orderbook.getBorrowerStatus(alice));

        vm.warp(block.timestamp + 1);
        priceFeed.setPrice(0.00001e18);
        assertTrue(
            orderbook.isLiquidatable(alice),
            "Borrower should be liquidatable"
        );
        plot("alice_2_2", orderbook.getBorrowerStatus(alice));

        vm.prank(liquidator);
        orderbook.deposit(10_000e18, 0);
        uint256 borrowerETHLockedBefore;
        (, , , borrowerETHLockedBefore) = orderbook.getUserCollateral(alice);
        vm.prank(liquidator);
        (uint256 actualAmountETH, uint256 targetAmountETH) = orderbook
            .liquidateBorrower(alice);

        uint256 liquidatorETHFreeAfter;
        uint256 liquidatorETHLockedAfter;
        uint256 aliceETHLockedAfter;
        (, , liquidatorETHFreeAfter, liquidatorETHLockedAfter) = orderbook
            .getUserCollateral(liquidator);
        (, , , aliceETHLockedAfter) = orderbook.getUserCollateral(liquidator);

        assertFalse(
            orderbook.isLiquidatable(alice),
            "Alice should not be eligible for liquidation anymore after the liquidation event"
        );
        assertEq(
            liquidatorETHFreeAfter,
            actualAmountETH,
            "liquidator.eth.free == actualAmountETH"
        );
        assertEq(
            aliceETHLockedAfter,
            borrowerETHLockedBefore - actualAmountETH,
            "alice.eth.locked == borrowerETHLockedBefore - actualAmountETH"
        );
        assertEq(
            liquidatorETHLockedAfter,
            0,
            "Liquidator ETH should be all free in this case"
        );

        plot("alice_2_3", orderbook.getBorrowerStatus(alice));
    }

    function test_experiment_3() public {
        console.log("Extension of the above with loan liquidation");

        console.log("context");
        priceFeed.setPrice(100e18);

        vm.prank(alice);
        orderbook.deposit(100e18, 20e18);
        vm.prank(bob);
        orderbook.deposit(100e18, 20e18);


        console.log(
            "Let's pretend she has some virtual collateral i.e. some loan she has given"
        );
        orderbook.setExpectedFV(alice, 3, 100e18);

        vm.prank(bob);
        orderbook.place(100e18, 10, 0.03e18);

        console.log("This should work now");
        vm.prank(alice);
        orderbook.pick(1, 100e18, 6);

        assertEq(
            orderbook.getCollateralRatio(alice),
            orderbook.CROpening(),
            "Alice Collateral Ratio == CROpening"
        );
        assertFalse(
            orderbook.isLiquidatable(alice),
            "Borrower should not be liquidatable"
        );

        plot("alice_3_0", orderbook.getBorrowerStatus(alice));


        vm.warp(block.timestamp + 1);
        priceFeed.setPrice(0.00001e18);
        assertTrue(
            orderbook.isLiquidatable(alice),
            "Borrower should be liquidatable"
        );
        plot("alice_3_1", orderbook.getBorrowerStatus(alice));


        vm.prank(liquidator);
        orderbook.deposit(10_000e18, 0);

        vm.prank(liquidator);
        orderbook.liquidateLoan(1);

        plot("alice_3_2", orderbook.getBorrowerStatus(alice));

        assertFalse(
            orderbook.isLiquidatable(alice),
            "Alice should not be eligible for liquidation anymore after the liquidation event"
        );
    }
}
