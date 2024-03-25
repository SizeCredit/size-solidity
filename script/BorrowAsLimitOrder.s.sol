// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

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

        Size size = Size(payable(sizeContractAddress));

        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 3 days;

        int256[] memory aprs = new int256[](2);
        aprs[0] = 0.1e18;
        aprs[1] = 0.2e18;

        uint256[] memory marketRateMultipliers = new uint256[](2);
        marketRateMultipliers[0] = 0;
        marketRateMultipliers[1] = 0;

        YieldCurve memory curveRelativeTime =
            YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});

        BorrowAsLimitOrderParams memory params =
            BorrowAsLimitOrderParams({openingLimitBorrowCR: 0, curveRelativeTime: curveRelativeTime});

        vm.startBroadcast(deployerPrivateKey);
        size.borrowAsLimitOrder(params);
        vm.stopBroadcast();
    }
}
