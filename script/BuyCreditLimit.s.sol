// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BuyCreditLimitScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size size = Size(payable(sizeContractAddress));

        console.log("Current Timestamp:", block.timestamp);

        uint256 maxDueDate = block.timestamp + 30 days; // timestamp + duedate in seconds

        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 3 days;

        int256[] memory aprs = new int256[](2);
        aprs[0] = 0.1e18;
        aprs[1] = 0.2e18;

        uint256[] memory marketRateMultipliers = new uint256[](2);
        marketRateMultipliers[0] = 1e18;
        marketRateMultipliers[1] = 1e18;

        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers});

        BuyCreditLimitParams memory params =
            BuyCreditLimitParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime});

        vm.startBroadcast(deployerPrivateKey);
        size.buyCreditLimit(params);
        vm.stopBroadcast();
    }
}
