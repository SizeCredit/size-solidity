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
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";
import {MorphoPriceFeedV2} from "@src/oracle/adapters/morpho/MorphoPriceFeedV2.sol";
import {PriceFeedMorphoChainlinkOracleV2} from "@src/oracle/v1.7.1/PriceFeedMorphoChainlinkOracleV2.sol";
import {PriceFeedChainlinkOnly4x} from "@src/oracle/v1.8/PriceFeedChainlinkOnly4x.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MainnetAddresses} from "@script/MainnetAddresses.s.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PendleChainlinkOracle} from "@pendle/contracts/oracles/PtYtLpOracle/chainlink/PendleChainlinkOracle.sol";
import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";
import {PriceFeedPendleSparkLinearDiscountChainlink} from
    "@src/oracle/v1.7.1/PriceFeedPendleSparkLinearDiscountChainlink.sol";
import {PriceFeedPendleTWAPChainlink} from "@src/oracle/v1.7.2/PriceFeedPendleTWAPChainlink.sol";

import {console} from "forge-std/console.sol";

contract ProposeSafeTxDeployMarketsSepScript is BaseScript, Networks, MainnetAddresses {
    using Tenderly for *;
    using Safe for *;

    uint256 public constant PT_STABLE_MARKET_CR_OPENING = 1.12e18;
    uint256 public constant PT_STABLE_MARKET_CR_LIQUIDATION = 1.09e18;
    uint256 public constant VOLATILE_MARKET_CR_OPENING = 1.3e18;
    uint256 public constant VOLATILE_MARKET_CR_LIQUIDATION = 1.2e18;
    uint256 public constant YB_STABLE_MARKET_CR_OPENING = 1.15e18;
    uint256 public constant YB_STABLE_MARKET_CR_LIQUIDATION = 1.1e18;

    enum MarketType {
        PT_STABLE,
        VOLATILE,
        YB_STABLE
    }

    struct UnderlyingCollateralTokenAndIsStable {
        IERC20Metadata underlyingCollateralToken;
        MarketType marketType;
        IPriceFeed priceFeed;
    }

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

    function priceFeedWbtcToUsdc() public returns (IPriceFeed) {
        PriceFeedChainlinkOnly4x wbtcToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_WBTC_BTC.aggregator),
            AggregatorV3Interface(CHAINLINK_BTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_WBTC_BTC.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_BTC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (WBTC/USDC)", address(wbtcToUsdc), price(wbtcToUsdc));
        return IPriceFeed(address(wbtcToUsdc));
    }

    function priceFeedCbbtcToUsdc() public returns (IPriceFeed) {
        PriceFeedChainlinkOnly4x cbbtcToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_cbBTC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_cbBTC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_cbBTC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (cbBTC/USDC)", address(cbbtcToUsdc), price(cbbtcToUsdc));
        return IPriceFeed(address(cbbtcToUsdc));
    }

    function priceFeedWethToUsdc() public returns (IPriceFeed) {
        PriceFeedChainlinkOnly4x wethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (WETH/USDC)", address(wethToUsdc), price(wethToUsdc));
        return IPriceFeed(address(wethToUsdc));
    }

    function priceFeedWstethToUsdc() public returns (IPriceFeed) {
        MorphoPriceFeedV2 wstethToUsdc = new MorphoPriceFeedV2(18, IOracle(MORPHO_wstETH_USDC_ORACLE), 18, 6);
        console.log("MorphoPriceFeedV2 (wstETH/USDC)", address(wstethToUsdc), price(wstethToUsdc));
        return IPriceFeed(address(wstethToUsdc));
    }

    function priceFeedWeethToUsdc() public returns (IPriceFeed) {
        PriceFeedChainlinkOnly4x weethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_weETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_weETH_ETH.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (weETH/USDC)", address(weethToUsdc), price(weethToUsdc));
        return IPriceFeed(address(weethToUsdc));
    }

    function priceFeedCbethToUsdc() public returns (IPriceFeed) {
        PriceFeedChainlinkOnly4x cbethToUsdc = new PriceFeedChainlinkOnly4x(
            AggregatorV3Interface(CHAINLINK_cbETH_ETH.aggregator),
            AggregatorV3Interface(CHAINLINK_ETH_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_cbETH_ETH.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_ETH_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log("PriceFeedChainlinkOnly4x (cbETH/USDC)", address(cbethToUsdc), price(cbethToUsdc));
        return IPriceFeed(address(cbethToUsdc));
    }

    function priceFeedPtSusde27Nov2025ToUsdc() public returns (IPriceFeed) {
        PriceFeedPendleSparkLinearDiscountChainlink ptSusde27Nov2025ToUsdc = new PriceFeedPendleSparkLinearDiscountChainlink(
            PendleSparkLinearDiscountOracle(PENDLE_SPARK_LINEAR_DISCOUNT_ORACLE_PT_sUSDE_27NOV2025_USDe),
            AggregatorV3Interface(CHAINLINK_USDe_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_USDe_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log(
            "PriceFeedPendleSparkLinearDiscountChainlink (PT-sUSDE-27NOV2025/USDC)",
            address(ptSusde27Nov2025ToUsdc),
            price(ptSusde27Nov2025ToUsdc)
        );
        return IPriceFeed(address(ptSusde27Nov2025ToUsdc));
    }

    function priceFeedPtWstusr29Jan2026ToUsdc() public returns (IPriceFeed) {
        PriceFeedPendleTWAPChainlink ptWstusr29Jan2026ToUsdc = new PriceFeedPendleTWAPChainlink(
            PendleChainlinkOracle(PENDLE_TWAP_CHAINLINK_ORACLE_PT_wstUSR_29JAN2026_USR),
            AggregatorV3Interface(CHAINLINK_USR_USD.aggregator),
            AggregatorV3Interface(CHAINLINK_USDC_USD.aggregator),
            1.1e18 * CHAINLINK_USR_USD.stalePriceInterval / 1e18,
            1.1e18 * CHAINLINK_USDC_USD.stalePriceInterval / 1e18
        );
        console.log(
            "PriceFeedPendleTWAPChainlink (PT-wstUSR-29JAN2026/USDC)",
            address(ptWstusr29Jan2026ToUsdc),
            price(ptWstusr29Jan2026ToUsdc)
        );
        return IPriceFeed(address(ptWstusr29Jan2026ToUsdc));
    }

    function run() external parseEnv deleteVirtualTestnets {
        vm.startBroadcast();

        UnderlyingCollateralTokenAndIsStable[8] memory underlyingCollateralTokensAndIsStable = [
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(WBTC), MarketType.VOLATILE, priceFeedWbtcToUsdc()),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(cbBTC), MarketType.VOLATILE, priceFeedCbbtcToUsdc()),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(WETH), MarketType.VOLATILE, priceFeedWethToUsdc()),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(wstETH), MarketType.VOLATILE, priceFeedWstethToUsdc()),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(weETH), MarketType.VOLATILE, priceFeedWeethToUsdc()),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(cbETH), MarketType.VOLATILE, priceFeedCbethToUsdc()),
            UnderlyingCollateralTokenAndIsStable(
                IERC20Metadata(PT_sUSDE_27NOV2025), MarketType.PT_STABLE, priceFeedPtSusde27Nov2025ToUsdc()
            ),
            UnderlyingCollateralTokenAndIsStable(
                IERC20Metadata(PT_wstUSR_29JAN2026), MarketType.PT_STABLE, priceFeedPtWstusr29Jan2026ToUsdc()
            )
        ];

        address[] memory targets = new address[](underlyingCollateralTokensAndIsStable.length);
        bytes[] memory datas = new bytes[](underlyingCollateralTokensAndIsStable.length);

        for (uint256 i = 0; i < underlyingCollateralTokensAndIsStable.length; i++) {
            IERC20Metadata underlyingCollateralToken =
                underlyingCollateralTokensAndIsStable[i].underlyingCollateralToken;
            MarketType marketType = underlyingCollateralTokensAndIsStable[i].marketType;
            IPriceFeed priceFeed = underlyingCollateralTokensAndIsStable[i].priceFeed;
            console.log("underlyingCollateralToken", address(underlyingCollateralToken));
            console.log("underlyingCollateralToken symbol", underlyingCollateralToken.symbol());
            console.log(
                "marketType",
                marketType == MarketType.PT_STABLE
                    ? "PT_STABLE"
                    : marketType == MarketType.VOLATILE ? "VOLATILE" : "YB_STABLE"
            );
            console.log("priceFeed", address(priceFeed));
            console.log("priceFeed price", priceFeed.getPrice());
            (
                InitializeFeeConfigParams memory feeConfigParams,
                InitializeRiskConfigParams memory riskConfigParams,
                InitializeOracleParams memory oracleParams,
                InitializeDataParams memory dataParams
            ) = getMarketParams(underlyingCollateralToken, marketType, priceFeed);

            targets[i] = address(sizeFactory);
            datas[i] =
                abi.encodeCall(ISizeFactory.createMarket, (feeConfigParams, riskConfigParams, oracleParams, dataParams));
        }

        vm.stopBroadcast();

        safe.proposeTransactions(targets, datas, signer, derivationPath);

        Tenderly.VirtualTestnet memory vnet = tenderly.createVirtualTestnet("deploy-markets-sep", block.chainid);
        tenderly.setStorageAt(vnet, safe.instance().safe, bytes32(uint256(4)), bytes32(uint256(1)));
        tenderly.sendTransaction(
            vnet.id, signer, safe.instance().safe, safe.getExecTransactionsData(targets, datas, signer, derivationPath)
        );
    }

    function getMarketParams(IERC20Metadata underlyingCollateralToken, MarketType marketType, IPriceFeed priceFeed)
        public
        view
        returns (
            InitializeFeeConfigParams memory feeConfigParams,
            InitializeRiskConfigParams memory riskConfigParams,
            InitializeOracleParams memory oracleParams,
            InitializeDataParams memory dataParams
        )
    {
        ISize market = sizeFactory.getMarket(0);
        feeConfigParams = market.feeConfig();

        riskConfigParams = market.riskConfig(); // crOpening, crLiquidation replaced below
        riskConfigParams.crOpening = marketType == MarketType.PT_STABLE
            ? PT_STABLE_MARKET_CR_OPENING
            : marketType == MarketType.VOLATILE ? VOLATILE_MARKET_CR_OPENING : YB_STABLE_MARKET_CR_OPENING;
        riskConfigParams.crLiquidation = marketType == MarketType.PT_STABLE
            ? PT_STABLE_MARKET_CR_LIQUIDATION
            : marketType == MarketType.VOLATILE ? VOLATILE_MARKET_CR_LIQUIDATION : YB_STABLE_MARKET_CR_LIQUIDATION;

        oracleParams = market.oracle(); // priceFeed replaced below
        oracleParams.priceFeed = address(priceFeed);

        DataView memory dataView = market.data();
        dataParams = InitializeDataParams({
            weth: contracts[block.chainid][Contract.WETH],
            underlyingCollateralToken: address(underlyingCollateralToken), // underlyingCollateralToken replaced below
            underlyingBorrowToken: address(dataView.underlyingBorrowToken),
            variablePool: address(dataView.variablePool),
            borrowTokenVault: address(dataView.borrowTokenVault),
            sizeFactory: address(sizeFactory)
        });
    }
}
