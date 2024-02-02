// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";
import "../src/libraries/fixed/actions/LendAsLimitOrder.sol";

contract LendAsLimitOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        address lender = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;

        address to = 0xCa57A4211d0F8819Bd0845e6E3eD6eDcBc245ffb;
        uint256 maxAmount = 10000;
        uint256 maxDueDate = 3600;

        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 3600;
        timeBuckets[1] = 7200;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1;
        rates[1] = 2;

        YieldCurve memory curveRelativeTime = YieldCurve({
            timeBuckets: timeBuckets,
            marketRateMultipliers: new int256[](2),
            rates: rates
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

/* struct LendAsLimitOrderParams {
    uint256 maxAmount; // in decimals (e.g. 1_000e6 for 1000 USDC)
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
} */
