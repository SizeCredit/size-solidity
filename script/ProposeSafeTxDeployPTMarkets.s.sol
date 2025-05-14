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

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IMorphoChainlinkOracleV2} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2.sol";
import {PriceFeedMorphoChainlinkOracleV2} from "@src/oracle/v1.7.1/PriceFeedMorphoChainlinkOracleV2.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PendleChainlinkOracle} from "@pendle/contracts/oracles/PtYtLpOracle/chainlink/PendleChainlinkOracle.sol";
import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";
import {PriceFeedPendleSparkLinearDiscountChainlink} from
    "@src/oracle/v1.7.1/PriceFeedPendleSparkLinearDiscountChainlink.sol";
import {PriceFeedPendleTWAPChainlink} from "@src/oracle/v1.7.2/PriceFeedPendleTWAPChainlink.sol";

import {console} from "forge-std/console.sol";

contract ProposeSafeTxDeployPTMarketsScript is BaseScript, Networks {
    using Tenderly for *;
    using Safe for *;

    address signer;
    string derivationPath;

    ISizeFactory private sizeFactory;
    address private safeAddress;

    modifier parseEnv() {
        signer = vm.envAddress("SIGNER");
        derivationPath = vm.envString("LEDGER_PATH");
        sizeFactory = ISizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);

        string memory accountSlug = vm.envString("TENDERLY_ACCOUNT_NAME");
        string memory projectSlug = vm.envString("TENDERLY_PROJECT_NAME");
        string memory accessKey = vm.envString("TENDERLY_ACCESS_KEY");

        tenderly.initialize(accountSlug, projectSlug, accessKey);

        safeAddress = vm.envAddress("OWNER");
        safe.initialize(safeAddress);

        _;
    }

    function run() external parseEnv deleteVirtualTestnets {
        vm.startBroadcast();

        (
            PendleSparkLinearDiscountOracle pendleOracle,
            AggregatorV3Interface underlyingChainlinkOracle,
            AggregatorV3Interface quoteChainlinkOracle,
            uint256 underlyingStalePriceInterval,
            uint256 quoteStalePriceInterval,
            IERC20Metadata baseToken,
        ) = priceFeedPendleChainlinkPtSusde30July2025UsdcMainnet();

        PriceFeedPendleSparkLinearDiscountChainlink ptSusde30July2025UsdcPriceFeed = new PriceFeedPendleSparkLinearDiscountChainlink(
            pendleOracle,
            underlyingChainlinkOracle,
            quoteChainlinkOracle,
            underlyingStalePriceInterval,
            quoteStalePriceInterval
        );

        console.log("ptSusde30July2025UsdcPriceFeed", address(ptSusde30July2025UsdcPriceFeed));
        console.log("ptSusde30July2025UsdcPriceFeed price", ptSusde30July2025UsdcPriceFeed.getPrice());

        (
            PendleChainlinkOracle pendleOracle2,
            AggregatorV3Interface underlyingChainlinkOracle2,
            AggregatorV3Interface quoteChainlinkOracle2,
            uint256 underlyingStalePriceInterval2,
            uint256 quoteStalePriceInterval2,
            IERC20Metadata baseToken2,
        ) = priceFeedPendleChainlinkWstusrUsdc24Sep2025Mainnet();

        PriceFeedPendleTWAPChainlink wstusrUsdc24Sep2025PriceFeed = new PriceFeedPendleTWAPChainlink(
            pendleOracle2,
            underlyingChainlinkOracle2,
            quoteChainlinkOracle2,
            underlyingStalePriceInterval2,
            quoteStalePriceInterval2
        );

        console.log("wstusrUsdc24Sep2025PriceFeed", address(wstusrUsdc24Sep2025PriceFeed));
        console.log("wstusrUsdc24Sep2025PriceFeed price", wstusrUsdc24Sep2025PriceFeed.getPrice());

        vm.stopBroadcast();

        ISize market = sizeFactory.getMarket(0);
        InitializeFeeConfigParams memory feeConfigParams = market.feeConfig();

        InitializeRiskConfigParams memory riskConfigParams = market.riskConfig(); // crOpening, crLiquidation replaced below
        riskConfigParams.crOpening = 1.12e18;
        riskConfigParams.crLiquidation = 1.09e18;

        InitializeOracleParams memory oracleParams = market.oracle(); // priceFeed replaced below

        DataView memory dataView = market.data();
        InitializeDataParams memory dataParams = InitializeDataParams({
            weth: contracts[block.chainid][Contract.WETH],
            underlyingCollateralToken: address(0), // underlyingCollateralToken replaced below
            underlyingBorrowToken: address(dataView.underlyingBorrowToken),
            variablePool: address(dataView.variablePool),
            borrowATokenV1_5: address(dataView.borrowAToken),
            sizeFactory: address(sizeFactory)
        });
        bytes[] memory datas = new bytes[](2);
        oracleParams.priceFeed = address(ptSusde30July2025UsdcPriceFeed);
        dataParams.underlyingCollateralToken = address(baseToken);
        datas[0] =
            abi.encodeCall(ISizeFactory.createMarket, (feeConfigParams, riskConfigParams, oracleParams, dataParams));
        oracleParams.priceFeed = address(wstusrUsdc24Sep2025PriceFeed);
        dataParams.underlyingCollateralToken = address(baseToken2);
        datas[1] =
            abi.encodeCall(ISizeFactory.createMarket, (feeConfigParams, riskConfigParams, oracleParams, dataParams));
        address[] memory targets = new address[](2);
        targets[0] = address(sizeFactory);
        targets[1] = address(sizeFactory);
        safe.proposeTransactions(targets, datas, signer, derivationPath);
        Tenderly.VirtualTestnet memory vnet = tenderly.createVirtualTestnet("pt-markets-2-vnet", block.chainid);
        bytes memory execTransactionsData = safe.getExecTransactionsData(targets, datas, signer, derivationPath);
        tenderly.setStorageAt(vnet, safe.instance().safe, bytes32(uint256(4)), bytes32(uint256(1)));
        tenderly.sendTransaction(vnet.id, signer, safe.instance().safe, execTransactionsData);
    }
}
