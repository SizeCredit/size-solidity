// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {SellCreditLimitParams} from "@src/libraries/actions/SellCreditLimit.sol";
import {Logger} from "@test/Logger.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract SellCreditLimitScript is Script, Logger {
    function run() external {
        console.log("SellCreditLimit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        Size size = Size(payable(sizeContractAddress));

        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 3 days;

        int256[] memory aprs = new int256[](2);
        aprs[0] = 0.1e18;
        aprs[1] = 0.2e18;

        uint256[] memory marketRateMultipliers = new uint256[](2);
        marketRateMultipliers[0] = 0;
        marketRateMultipliers[1] = 0;

        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers});

        SellCreditLimitParams memory params = SellCreditLimitParams({curveRelativeTime: curveRelativeTime});

        vm.startBroadcast(deployerPrivateKey);
        size.sellCreditLimit(params);
        vm.stopBroadcast();
    }
}
