// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract LendAsLimitOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        console.log("Current Timestamp:", block.timestamp);

        uint256 maxDueDate = block.timestamp + 30 days; // timestamp + duedate in seconds

        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 3 days;

        int256[] memory aprs = new int256[](2);
        aprs[0] = 0.1e18;
        aprs[1] = 0.2e18;

        uint256[] memory marketRateMultipliers = new uint256[](2);
        marketRateMultipliers[0] = 1e18;
        marketRateMultipliers[1] = 1e18;

        YieldCurve memory curveRelativeTime =
            YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});

        LendAsLimitOrderParams memory params =
            LendAsLimitOrderParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.lendAsLimitOrder(params);
        vm.stopBroadcast();
    }
}
