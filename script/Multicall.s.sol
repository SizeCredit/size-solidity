// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";

import {Script} from "forge-std/Script.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {Script} from "forge-std/Script.sol";

contract MulticallScript is Script, Logger {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        Size sizeContract = Size(sizeContractAddress);

        uint256 dueDate = block.timestamp + 2 days;
        uint256 apr = sizeContract.getLoanOfferAPR(lender, dueDate);

        bytes memory depositCall = abi.encodeCall(
            Size.deposit, DepositParams({token: wethAddress, amount: 0.04e18, to: borrower, variable: false})
        );

        bytes memory borrowCall = abi.encodeCall(
            Size.borrowAsMarketOrder,
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: 51e6,
                dueDate: dueDate,
                deadline: block.timestamp,
                maxAPR: apr,
                exactAmountIn: false,
                receivableCreditPositionIds: new uint256[](0)
            })
        );

        YieldCurve memory curve = createYieldCurve();
        bytes memory lendLimitOrderCall = abi.encodeCall(
            Size.lendAsLimitOrder,
            LendAsLimitOrderParams({maxDueDate: block.timestamp + 30 days, curveRelativeTime: curve})
        );

        bytes[] memory calls = new bytes[](3);
        calls[0] = depositCall;
        calls[1] = borrowCall;
        calls[2] = lendLimitOrderCall;

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.multicall(calls);
        vm.stopBroadcast();
    }

    function createYieldCurve() internal pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 3 days;

        int256[] memory aprs = new int256[](2);
        aprs[0] = 0.1e18; // 10%
        aprs[1] = 0.2e18; // 20%

        uint256[] memory marketRateMultipliers = new uint256[](2);
        marketRateMultipliers[0] = 1e18; // 1x
        marketRateMultipliers[1] = 1e18; // 1x

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }
}
