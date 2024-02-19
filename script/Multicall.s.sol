// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../src/Size.sol";
import "forge-std/Script.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

contract DepositScript is Script {
    function run() external {
        console.log("deposit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        address lenderTest = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("LenderTest", lenderTest);

        Size sizeContract = Size(sizeContractAddress);

        bytes memory depositCall = prepareDepositCall(
            wethAddress,
            0.04e18,
            lenderTest
        );
        bytes memory borrowCall = prepareBorrowAsMarketOrderCall(
            borrower,
            51e6,
            block.timestamp + 2 days
        );
        bytes memory lendLimitOrderCall = prepareLendAsLimitOrderCall(
            block.timestamp + 30 days
        );

        bytes[] memory calls = new bytes[](3);
        calls[0] = depositCall;
        calls[1] = borrowCall;
        calls[2] = lendLimitOrderCall;

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.multicall(calls);
        vm.stopBroadcast();
    }

    function prepareDepositCall(
        address token,
        uint256 amount,
        address to
    ) internal pure returns (bytes memory) {
        DepositParams memory params = DepositParams({
            token: token,
            amount: amount,
            to: to
        });
        return
            abi.encodeWithSelector(
                Size.deposit.selector,
                params.token,
                params.amount,
                params.to
            );
    }

    function prepareBorrowAsMarketOrderCall(
        address lender,
        uint256 amount,
        uint256 dueDate
    ) internal pure returns (bytes memory) {
        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: lender,
            amount: amount,
            dueDate: dueDate,
            exactAmountIn: false,
            receivableCreditPositionIds: new uint256[](0)
        });
        return abi.encodeCall(Size.borrowAsMarketOrder, (params));
    }

    function prepareLendAsLimitOrderCall(
        uint256 maxDueDate
    ) internal view returns (bytes memory) {
        YieldCurve memory curve = createYieldCurve();
        LendAsLimitOrderParams memory params = LendAsLimitOrderParams({
            maxDueDate: maxDueDate,
            curveRelativeTime: curve
        });
        return abi.encodeCall(Size.lendAsLimitOrder, (params));
    }

    function createYieldCurve() internal pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 3 days;

        uint256[] memory rates = new uint256[](2);
        rates[0] = 0.1e18; // 10%
        rates[1] = 0.2e18; // 20%

        int256[] memory marketRateMultipliers = new int256[](2);
        marketRateMultipliers[0] = 1e18; // 1x
        marketRateMultipliers[1] = 1e18; // 1x

        return
            YieldCurve({
                timeBuckets: timeBuckets,
                rates: rates,
                marketRateMultipliers: marketRateMultipliers
            });
    }
}
