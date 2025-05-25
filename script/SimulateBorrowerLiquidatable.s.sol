// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {RESERVED_ID} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";
import {BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GetCalldataScript is Script {
    using Tenderly for *;

    Tenderly.Client tenderly;

    function setUp() public {
        string memory accountSlug = vm.envString("TENDERLY_ACCOUNT_NAME");
        string memory projectSlug = vm.envString("TENDERLY_PROJECT_NAME");
        string memory accessKey = vm.envString("TENDERLY_ACCESS_KEY");

        tenderly.initialize(accountSlug, projectSlug, accessKey);
    }

    function run() external {
        console.log("GetCalldata...");

        address size = vm.envAddress("SIZE_ADDRESS");
        address borrower = vm.envAddress("BORROWER");
        address lender = vm.envAddress("LENDER");

        console.log("size", size);
        console.log("borrower", borrower);
        console.log("lender", lender);

        Tenderly.VirtualTestnet memory vnet =
            tenderly.createVirtualTestnet(string.concat("vnet-", vm.toString(block.chainid)), 1_000_000 + block.chainid);

        IERC20Metadata underlyingBorrowToken = ISize(size).data().underlyingBorrowToken;

        tenderly.sendTransaction(
            vnet.id, borrower, address(underlyingBorrowToken), abi.encodeCall(IERC20.approve, (address(size), 2000e18))
        );
        tenderly.sendTransaction(
            vnet.id,
            borrower,
            address(size),
            abi.encodeCall(
                ISize.deposit, (DepositParams({token: address(underlyingBorrowToken), amount: 2000e18, to: borrower}))
            )
        );
        uint256[] memory tenors = new uint256[](1);
        tenors[0] = 30 days;
        int256[] memory aprs = new int256[](1);
        aprs[0] = 0.05e18;
        uint256[] memory marketRateMultipliers = new uint256[](1);
        marketRateMultipliers[0] = 0;
        YieldCurve memory curve = YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
        tenderly.sendTransaction(
            vnet.id,
            lender,
            address(size),
            abi.encodeCall(
                ISize.buyCreditLimit, (BuyCreditLimitParams({maxDueDate: type(uint256).max, curveRelativeTime: curve}))
            )
        );
        tenderly.sendTransaction(
            vnet.id,
            lender,
            address(size),
            abi.encodeCall(
                ISize.sellCreditMarket,
                (
                    SellCreditMarketParams({
                        lender: lender,
                        creditPositionId: RESERVED_ID,
                        tenor: 30 days,
                        amount: 1000e6,
                        deadline: type(uint256).max,
                        maxAPR: type(uint256).max,
                        exactAmountIn: false,
                        collectionId: RESERVED_ID,
                        rateProvider: address(0)
                    })
                )
            )
        );
    }
}
