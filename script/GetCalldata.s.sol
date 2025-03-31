// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {RESERVED_ID} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";
import {BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GetCalldataScript is Script {
    function run() external view {
        console.log("GetCalldata...");

        address size = vm.envAddress("SIZE_ADDRESS");
        address token = vm.envAddress("TOKEN");
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address lender = vm.envAddress("LENDER");

        console.log("size", size);
        console.log("token", token);
        console.log("deployer", deployer);
        console.log("lender", lender);

        bytes memory approve = abi.encodeCall(IERC20.approve, (address(size), 2000e18));

        console.log(block.timestamp);

        console.logBytes(approve);

        bytes memory deposit =
            abi.encodeCall(ISize.deposit, (DepositParams({token: token, amount: 2000e18, to: deployer})));

        console.logBytes(deposit);

        uint256[] memory tenors = new uint256[](1);
        tenors[0] = 30 days;
        int256[] memory aprs = new int256[](1);
        aprs[0] = 0.05e18;
        uint256[] memory marketRateMultipliers = new uint256[](1);
        marketRateMultipliers[0] = 0;

        YieldCurve memory curve = YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
        bytes memory buyCreditLimit = abi.encodeCall(
            ISize.buyCreditLimit, (BuyCreditLimitParams({maxDueDate: type(uint256).max, curveRelativeTime: curve}))
        );

        console.logBytes(buyCreditLimit);

        bytes memory sellCreditMarket = abi.encodeCall(
            ISize.sellCreditMarket,
            (
                SellCreditMarketParams({
                    lender: lender,
                    creditPositionId: RESERVED_ID,
                    tenor: 30 days,
                    amount: 1000e6,
                    deadline: type(uint256).max,
                    maxAPR: type(uint256).max,
                    exactAmountIn: false
                })
            )
        );

        console.logBytes(sellCreditMarket);
    }
}
