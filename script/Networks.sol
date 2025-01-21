// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct NetworkConfiguration {
    address weth;
    address underlyingCollateralToken;
    address underlyingBorrowToken;
    address variablePool;
    uint256 fragmentationFee;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 borrowATokenCap;
    PriceFeedParams priceFeedParams;
}

abstract contract Networks {
    error InvalidNetworkConfiguration(string networkConfiguration);

    uint256 public constant BASE_MAINNET = 8453;
    uint256 public constant BASE_SEPOLIA = 84532;

    function params(string memory networkConfiguration) public pure returns (NetworkConfiguration memory) {
        if (Strings.equal(networkConfiguration, "base-sepolia-weth-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0x4200000000000000000000000000000000000006,
                underlyingBorrowToken: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
                variablePool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0x4200000000000000000000000000000000000006),
                    quoteToken: IERC20Metadata(0x036CbD53842c5426634e7929541eC2318f3dCF7e),
                    baseAggregator: AggregatorV3Interface(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165),
                    quoteAggregator: AggregatorV3Interface(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1),
                    baseStalePriceInterval: 1200 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(address(0))
                })
            });
        } else if (Strings.equal(networkConfiguration, "base-sepolia-link-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
                underlyingBorrowToken: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
                variablePool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0xE4aB69C077896252FAFBD49EFD26B5D171A32410),
                    quoteToken: IERC20Metadata(0x036CbD53842c5426634e7929541eC2318f3dCF7e),
                    baseAggregator: AggregatorV3Interface(0xb113F5A928BCfF189C998ab20d753a47F9dE5A61),
                    quoteAggregator: AggregatorV3Interface(0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165),
                    baseStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(address(0))
                })
            });
        } else if (Strings.equal(networkConfiguration, "mainnet-production")) {
            return NetworkConfiguration({
                weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                underlyingCollateralToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                underlyingBorrowToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                variablePool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2),
                    quoteToken: IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
                    baseAggregator: AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
                    quoteAggregator: AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6),
                    baseStalePriceInterval: 3600 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(address(0))
                })
            });
        } else if (Strings.equal(networkConfiguration, "base-mocks")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0x4200000000000000000000000000000000000006,
                underlyingBorrowToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: address(0),
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0x4200000000000000000000000000000000000006),
                    quoteToken: IERC20Metadata(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),
                    baseAggregator: AggregatorV3Interface(address(0)),
                    quoteAggregator: AggregatorV3Interface(address(0)),
                    baseStalePriceInterval: 0,
                    quoteStalePriceInterval: 0,
                    sequencerUptimeFeed: AggregatorV3Interface(address(0))
                })
            });
        } else if (Strings.equal(networkConfiguration, "base-production-weth-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0x4200000000000000000000000000000000000006,
                underlyingBorrowToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0x4200000000000000000000000000000000000006),
                    quoteToken: IERC20Metadata(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),
                    baseAggregator: AggregatorV3Interface(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70),
                    quoteAggregator: AggregatorV3Interface(0x7e860098F58bBFC8648a4311b374B1D669a2bc6B),
                    baseStalePriceInterval: 1200 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433)
                })
            });
        } else if (Strings.equal(networkConfiguration, "base-production-cbbtc-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
                underlyingBorrowToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf),
                    quoteToken: IERC20Metadata(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),
                    baseAggregator: AggregatorV3Interface(0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D),
                    quoteAggregator: AggregatorV3Interface(0x7e860098F58bBFC8648a4311b374B1D669a2bc6B),
                    baseStalePriceInterval: 1200 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433)
                })
            });
        } else if (Strings.equal(networkConfiguration, "base-production-wsteth-weth")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452,
                underlyingBorrowToken: 0x4200000000000000000000000000000000000006,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                fragmentationFee: 0.0005e18,
                crOpening: 1.3e18,
                crLiquidation: 1.1e18,
                minimumCreditBorrowAToken: 0.005e18,
                borrowATokenCap: 500e18,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452),
                    quoteToken: IERC20Metadata(0x4200000000000000000000000000000000000006),
                    baseAggregator: AggregatorV3Interface(0x43a5C292A453A3bF3606fa856197f09D7B74251a),
                    quoteAggregator: AggregatorV3Interface(0x43a5C292A453A3bF3606fa856197f09D7B74251a),
                    baseStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433)
                })
            });
        } else if (Strings.equal(networkConfiguration, "arbitrum-production-susde-usdc")) {
            return NetworkConfiguration({
                weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
                underlyingCollateralToken: 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2,
                underlyingBorrowToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                variablePool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
                fragmentationFee: 1e6,
                crOpening: 1.3e18,
                crLiquidation: 1.1e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6,
                priceFeedParams: PriceFeedParams({
                    twapWindow: 0,
                    averageBlockTime: 0,
                    uniswapV3Pool: IUniswapV3Pool(address(0)),
                    baseToken: IERC20Metadata(0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2),
                    quoteToken: IERC20Metadata(0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
                    baseAggregator: AggregatorV3Interface(0xf2215b9c35b1697B5f47e407c917a40D055E68d7),
                    quoteAggregator: AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3),
                    baseStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
                    sequencerUptimeFeed: AggregatorV3Interface(0xFdB631F5EE196F0ed6FAa767959853A9F217697D)
                })
            });
        } else {
            revert InvalidNetworkConfiguration(networkConfiguration);
        }
    }

    function priceFeedVirtualUsdcBaseMainnet()
        public
        pure
        returns (AggregatorV3Interface sequencerUptimeFeed, PriceFeedParams memory base, PriceFeedParams memory quote)
    {
        sequencerUptimeFeed = AggregatorV3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433);
        base = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(0x1D4daB3f27C7F656b6323C1D6Ef713b48A8f72F1), // VIRTUAL/WETH Uniswap v3 0.3% pool
            twapWindow: 10 minutes,
            averageBlockTime: 2 seconds,
            baseToken: IERC20Metadata(0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b), // VIRTUAL
            quoteToken: IERC20Metadata(0x4200000000000000000000000000000000000006), // WETH
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(0))
        });
        quote = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(0xd0b53D9277642d899DF5C87A3966A349A798F224), // WETH/USDC Uniswap v3 0.05% pool
            twapWindow: 10 minutes,
            averageBlockTime: 2 seconds,
            baseToken: IERC20Metadata(0x4200000000000000000000000000000000000006), // WETH
            quoteToken: IERC20Metadata(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913), // USDC
            baseAggregator: AggregatorV3Interface(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70),
            quoteAggregator: AggregatorV3Interface(0x7e860098F58bBFC8648a4311b374B1D669a2bc6B),
            baseStalePriceInterval: 1200 * 1.1e18 / 1e18,
            quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
            sequencerUptimeFeed: AggregatorV3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433)
        });
    }

    function priceFeedsUSDeToUsdcMainnet()
        public
        pure
        returns (
            PriceFeedParams memory chainlinkPriceFeedParams,
            PriceFeedParams memory uniswapV3BasePriceFeedParams,
            PriceFeedParams memory uniswapV3QuotePriceFeedParams
        )
    {
        chainlinkPriceFeedParams = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(address(0)),
            baseToken: IERC20Metadata(address(0)),
            quoteToken: IERC20Metadata(address(0)),
            twapWindow: 0,
            averageBlockTime: 0,
            baseAggregator: AggregatorV3Interface(0xFF3BC18cCBd5999CE63E788A1c250a88626aD099),
            quoteAggregator: AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6),
            baseStalePriceInterval: 86400 * 1.1e18 / 1e18,
            quoteStalePriceInterval: 86400 * 1.1e18 / 1e18,
            sequencerUptimeFeed: AggregatorV3Interface(address(0))
        });
        uniswapV3BasePriceFeedParams = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(0x867B321132B18B5BF3775c0D9040D1872979422E),
            baseToken: IERC20Metadata(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497),
            quoteToken: IERC20Metadata(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            twapWindow: 30 minutes,
            averageBlockTime: 12 seconds,
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(0))
        });
        uniswapV3QuotePriceFeedParams = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(0x3416cF6C708Da44DB2624D63ea0AAef7113527C6),
            baseToken: IERC20Metadata(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            quoteToken: IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            twapWindow: 30 minutes,
            averageBlockTime: 12 seconds,
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(0))
        });
    }

    function priceFeedAixbtUsdcBaseMainnet()
        public
        pure
        returns (AggregatorV3Interface sequencerUptimeFeed, PriceFeedParams memory baseToQuoteParams)
    {
        sequencerUptimeFeed = AggregatorV3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433);
        baseToQuoteParams = PriceFeedParams({
            uniswapV3Pool: IUniswapV3Pool(0xf1Fdc83c3A336bdbDC9fB06e318B08EadDC82FF4), // AIXBT/USDC Uniswap v3 0.3% pool
            twapWindow: 10 minutes,
            averageBlockTime: 2 seconds,
            baseToken: IERC20Metadata(0x4F9Fd6Be4a90f2620860d680c0d4d5Fb53d1A825), // AIXBT
            quoteToken: IERC20Metadata(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913), // USDC
            baseAggregator: AggregatorV3Interface(address(0)),
            quoteAggregator: AggregatorV3Interface(address(0)),
            baseStalePriceInterval: 0,
            quoteStalePriceInterval: 0,
            sequencerUptimeFeed: AggregatorV3Interface(address(0))
        });
    }
}
