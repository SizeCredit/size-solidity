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

    function run() external parseEnv deleteVirtualTestnets {
        vm.startBroadcast();

        UnderlyingCollateralTokenAndIsStable[11] memory underlyingCollateralTokensAndIsStable = [
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(WBTC), MarketType.VOLATILE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(cbBTC), MarketType.VOLATILE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(WETH), MarketType.VOLATILE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(wstETH), MarketType.VOLATILE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(weETH), MarketType.VOLATILE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(cbETH), MarketType.VOLATILE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(
                IERC20Metadata(PT_sUSDE_27NOV2025), MarketType.PT_STABLE, IPriceFeed(address(0))
            ),
            UnderlyingCollateralTokenAndIsStable(
                IERC20Metadata(PT_wstUSR_29JAN2026), MarketType.PT_STABLE, IPriceFeed(address(0))
            ),
            UnderlyingCollateralTokenAndIsStable(
                IERC20Metadata(PT_cUSDO_20NOV2025), MarketType.PT_STABLE, IPriceFeed(address(0))
            ),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(wstUSR), MarketType.YB_STABLE, IPriceFeed(address(0))),
            UnderlyingCollateralTokenAndIsStable(IERC20Metadata(sUSDS), MarketType.YB_STABLE, IPriceFeed(address(0)))
        ];

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
        }

        vm.stopBroadcast();
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
