// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Safe} from "@safe-utils/Safe.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {Contract, Networks} from "@script/Networks.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {DataView} from "@src/market/SizeViewData.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";
import {IMorphoChainlinkOracleV2} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2.sol";
import {PriceFeedMorphoChainlinkOracleV2} from "@src/oracle/v1.7.1/PriceFeedMorphoChainlinkOracleV2.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

import {console} from "forge-std/console.sol";

contract ProposeSafeTxDeployPTMarketsScript is BaseScript, Networks {
    using Tenderly for *;
    using Safe for *;

    address sender;
    Tenderly.Client tenderly;
    Safe.Client safe;

    ISizeFactory private sizeFactory;
    address private safeAddress;

    modifier parseEnv() {
        sender = vm.envAddress("SENDER");

        sizeFactory = ISizeFactory(addresses[block.chainid][Contract.SIZE_FACTORY]);

        string memory accountSlug = vm.envString("TENDERLY_ACCOUNT_NAME");
        string memory projectSlug = vm.envString("TENDERLY_PROJECT_NAME");
        string memory accessKey = vm.envString("TENDERLY_ACCESS_KEY");

        tenderly.initialize(accountSlug, projectSlug, accessKey);

        safeAddress = vm.envAddress("SAFE_ADDRESS");
        safe.initialize(safeAddress);

        _;
    }

    function run() external parseEnv ignoreGas {
        (IMorphoChainlinkOracleV2 morphoOracle, IERC20Metadata baseToken,) =
            priceFeedMorphoPtSusde29May2025UsdcMainnet();

        address weth = addresses[block.chainid][Contract.WETH];

        ISize market = sizeFactory.getMarket(0);
        InitializeFeeConfigParams memory feeConfigParams = market.feeConfig();

        InitializeRiskConfigParams memory riskConfigParams = market.riskConfig();
        riskConfigParams.crOpening = 1.12e18;
        riskConfigParams.crLiquidation = 1.09e18;

        InitializeOracleParams memory oracleParams = market.oracle();
        PriceFeedMorphoChainlinkOracleV2 priceFeedMorphoChainlinkOracleV2 =
            new PriceFeedMorphoChainlinkOracleV2(morphoOracle);
        oracleParams.priceFeed = address(priceFeedMorphoChainlinkOracleV2);

        DataView memory dataView = market.data();
        InitializeDataParams memory dataParams = InitializeDataParams({
            weth: weth,
            underlyingCollateralToken: address(baseToken),
            underlyingBorrowToken: address(dataView.underlyingBorrowToken),
            variablePool: address(dataView.variablePool),
            borrowATokenV1_5: address(dataView.borrowAToken),
            sizeFactory: address(sizeFactory)
        });
        bytes memory data =
            abi.encodeCall(ISizeFactory.createMarket, (feeConfigParams, riskConfigParams, oracleParams, dataParams));
        address to = address(sizeFactory);
        safe.proposeTransaction(to, data, sender);
        Tenderly.VirtualTestnet memory vnet =
            tenderly.createVirtualTestnet("pt-markets-vnet", 1_000_000 + block.chainid);
        bytes memory execTransactionData = safe.getExecTransactionData(to, data, sender);
        tenderly.sendTransaction(vnet.id, safeAddress, to, execTransactionData);
    }
}
