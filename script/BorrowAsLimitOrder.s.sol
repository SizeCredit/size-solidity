// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "../src/libraries/fixed/YieldCurveLibrary.sol";
import "forge-std/Script.sol";

contract BorrowLimitOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        Size sizeContract = Size(sizeContractAddress);

        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 86400;
        timeBuckets[1] = 7200000;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1e18;
        rates[1] = 2e18;

        int256[] memory marketRateMultipliers = new int256[](2);
        marketRateMultipliers[0] = int256(0);
        marketRateMultipliers[1] = int256(0);

        YieldCurve memory curveRelativeTime =
            YieldCurve({timeBuckets: timeBuckets, rates: rates, marketRateMultipliers: marketRateMultipliers});

        BorrowAsLimitOrderParams memory params =
            BorrowAsLimitOrderParams({riskCR: 1e18, curveRelativeTime: curveRelativeTime});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowAsLimitOrder(params);
        vm.stopBroadcast();
    }
}
