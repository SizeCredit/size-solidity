// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "../src/Orderbook.sol";
import "./mocks/PriceFeedMock.sol";
import "./libraries/PlotLibrary.sol";
import "../src/libraries/UserLibrary.sol";
import "../src/libraries/RealCollateralLibrary.sol";
import "../src/libraries/OfferLibrary.sol";
import "../src/libraries/ScheduleLibrary.sol";

contract OrderbookTest is Test {
    using PlotLibrary for BorrowerStatus;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    Orderbook public orderbook;
    PriceFeedMock public priceFeed;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public james = address(0x3);

    User internal aliceUser;
    User internal bobUser;
    User internal jamesUser;

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new Orderbook()),
            abi.encodeWithSelector(
                Orderbook.initialize.selector,
                address(this),
                priceFeed,
                12,
                1.5e18,
                1.3e18
            )
        );
        orderbook = Orderbook(address(proxy));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(james, "james");
    }

    function testExperiment1() public {
        console.log("Basic Functioning");
        console.log("Place an offer");
        console.log("Pick a loan from that offer");

        uint256[] memory empty;
        EnumerableMap.UintToUintMap storage emptyMap;

        console.log("context");
        priceFeed.setPrice(100e18);

        bobUser.account = bob;
        bobUser.cash.free = 100e18;

        aliceUser.account = alice;
        aliceUser.cash.free = 100e18;

        jamesUser.account = james;
        jamesUser.cash.free = 100e18;

        console.log(
            "Let's pretend she has some virtual collateral i.e. some loan she has given"
        );
        aliceUser.schedule.expectedFV.set(3, 100);

        orderbook.place(100e18, 10, 0.03e18);

        console.log("This will revert");
        vm.prank(alice);
        vm.expectRevert();
        orderbook.pick(0, 100e18, 6);

        console.log("This will succeed");
        vm.prank(alice);
        orderbook.pick(0, 50e18, 6);

        orderbook.getBorrowerStatus(bob).plot();
        orderbook.getBorrowerStatus(alice).plot();
        orderbook.getBorrowerStatus(bob).plot();
    }
}
