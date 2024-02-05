// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "../src/libraries/fixed/actions/LendAsLimitOrder.sol";
import "forge-std/Script.sol";

contract LendAsLimitOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        //TODO, get timestamp from chain
        uint256 maxDueDate = 1709753450; // timestamp + duedate in seconds

        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 36000;
        timeBuckets[1] = 72000;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1e18;
        rates[1] = 2e18;

        int256[] memory marketRateMultipliers = new int256[](2);
        marketRateMultipliers[0] = 12;
        marketRateMultipliers[1] = 12;

        YieldCurve memory curveRelativeTime = YieldCurve({
            timeBuckets: timeBuckets,
            rates: rates,
            marketRateMultipliers: marketRateMultipliers //new int256[](2)
        });

        LendAsLimitOrderParams memory params = LendAsLimitOrderParams({
            maxDueDate: maxDueDate,
            curveRelativeTime: curveRelativeTime
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.lendAsLimitOrder(params);
        vm.stopBroadcast();
    }
}
