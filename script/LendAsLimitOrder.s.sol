// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "../src/libraries/fixed/actions/LendAsLimitOrder.sol";
import "forge-std/Script.sol";
import "./TimestampHelper.sol";

contract LendAsLimitOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        TimestampHelper helper = new TimestampHelper();
        uint256 currentTimestamp = helper.getCurrentTimestamp();
        console.log("Current Timestamp:", currentTimestamp);

        uint256 maxDueDate = (currentTimestamp + 2592000); // timestamp + duedate in seconds

        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 86400;
        timeBuckets[1] = 720000;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1e18;
        rates[1] = 2e18;

        int256[] memory marketRateMultipliers = new int256[](2);
        marketRateMultipliers[0] = 1;
        marketRateMultipliers[1] = 1;

        YieldCurve memory curveRelativeTime = YieldCurve({
            timeBuckets: timeBuckets,
            rates: rates,
            marketRateMultipliers: marketRateMultipliers
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
