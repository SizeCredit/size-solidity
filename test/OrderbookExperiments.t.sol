// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@solplot/Plot.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./mocks/OrderbookMock.sol";
import "./mocks/PriceFeedMock.sol";
import "../src/libraries/UserLibrary.sol";
import "../src/libraries/RealCollateralLibrary.sol";
import "../src/libraries/OfferLibrary.sol";
import "../src/libraries/ScheduleLibrary.sol";

contract OrderbookTest is Test, Plot {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    OrderbookMock public orderbook;
    PriceFeedMock public priceFeed;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public james = address(0x30000);

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
        vm.label(james, "james");
    }

    function test_experiment_1() public {
        console.log("Basic Functioning");
        console.log("Place an offer");
        console.log("Pick a loan from that offer");

        console.log("context");
        priceFeed.setPrice(100e18);

        vm.prank(alice);
        orderbook.addCash(100e18);
        vm.prank(bob);
        orderbook.addCash(100e18);
        vm.prank(james);
        orderbook.addCash(100e18);

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
        orderbook.addCash(100e18);
        vm.prank(alice);
        orderbook.addEth(20e18);
        vm.prank(bob);
        orderbook.addCash(100e18);
        vm.prank(bob);
        orderbook.addEth(20e18);

        vm.prank(bob);
        orderbook.place(100e18, 10, 0.03e18);

        console.log("This should work now");
        plot("alice_2", orderbook.getBorrowerStatus(alice));

        vm.prank(alice);
        orderbook.pick(1, 100e18, 6);

        assertEq(
            orderbook.getCollateralRatio(alice),
            orderbook.CROpening(),
            "Alice Collateral Ratio == CROpening"
        );
        assertTrue(!orderbook.isLiquidatable(alice), "Borrower should not be liquidatable");

        plot("alice_2_after_pick", orderbook.getBorrowerStatus(alice));
    }

    function plot(string memory filename, BorrowerStatus memory self) private {
        try vm.createDir("./plots", false) {} catch {}
        try
            vm.removeFile(string.concat("./plots/", filename, ".csv"))
        {} catch {}

        uint256 length = self.RANC.length;

        // Use first row as legend
        // Make sure the same amount of columns are included for the legend
        vm.writeLine(
            string.concat("./plots/", filename, ".csv"),
            "x axis,expectedFV,unlocked,dueFV,RANC,"
        );

        // Create input csv
        for (uint256 i; i < length; i++) {
            int256[] memory cols = new int256[](5);

            cols[0] = int256(i * 1e18);
            cols[1] = int256(self.expectedFV[i]);
            cols[2] = int256(self.unlocked[i]);
            cols[3] = int256(self.dueFV[i]);
            cols[4] = int256(self.RANC[i]);

            writeRowToCSV(string.concat("./plots/", filename, ".csv"), cols);
        }

        // Create output svg with values denominated in wad
        plot({
            inputCsv: string.concat("./plots/", filename, ".csv"),
            outputSvg: string.concat("./plots/", filename, ".svg"),
            inputDecimals: 18,
            totalColumns: 5,
            legend: true
        });
    }
}
