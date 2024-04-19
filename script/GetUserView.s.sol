// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SizeView} from "@src/SizeView.sol";

import {Logger} from "@test/Logger.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GetUserViewScript is Script, Logger {
    using OfferLibrary for LoanOffer;

    function run() external {
        console.log("GetUserView...");

        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address lender = vm.envAddress("LENDER");

        SizeView size = SizeView(sizeContractAddress);

        vm.startBroadcast();
        _log(size.getUserView(lender));
        uint256 dueDate = block.timestamp + 2 days;
        console.log(block.timestamp);

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
        LoanOffer memory offer =
            LoanOffer({maxDueDate: block.timestamp + 30 days, curveRelativeTime: curveRelativeTime});

        console.log(
            offer.getRatePerMaturityByDueDate(
                IVariablePoolBorrowRateFeed(size.oracle().variablePoolBorrowRateFeed), dueDate
            )
        );
        console.log(size.getLoanOfferAPR(lender, block.timestamp + 86400));
        vm.stopBroadcast();
    }
}
