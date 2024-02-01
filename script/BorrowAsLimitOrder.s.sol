// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";
import "../src/libraries/fixed/YieldCurveLibrary.sol";

contract BorrowLimitOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        Size sizeContract = Size(sizeContractAddress);

        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 3600;
        timeBuckets[1] = 7200;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1e18;
        rates[1] = 2e18;

        YieldCurve memory curveRelativeTime = YieldCurve({
            timeBuckets: timeBuckets,
            marketRateMultipliers: new int256[](2),
            rates: rates
        });

        BorrowAsLimitOrderParams memory params = BorrowAsLimitOrderParams({
            riskCR: 0,
            curveRelativeTime: curveRelativeTime
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowAsLimitOrder(params);
        vm.stopBroadcast();
    }
}
