// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BorrowAsLimitOrder is Script, Logger {
    function run() external {
        console.log("BorrowAsLimitOrder...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        Size sizeContract = Size(sizeContractAddress);

        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 3 days;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 0.1e18;
        rates[1] = 0.2e18;

        int256[] memory marketRateMultipliers = new int256[](2);
        marketRateMultipliers[0] = int256(0);
        marketRateMultipliers[1] = int256(0);

        YieldCurve memory curveRelativeTime =
            YieldCurve({timeBuckets: timeBuckets, rates: rates, marketRateMultipliers: marketRateMultipliers});

        BorrowAsLimitOrderParams memory params =
            BorrowAsLimitOrderParams({openingLimitBorrowCR: 0, curveRelativeTime: curveRelativeTime});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowAsLimitOrder(params);
        vm.stopBroadcast();

        logPositions(address(sizeContract));
    }
}
