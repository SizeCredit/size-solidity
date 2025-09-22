// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

abstract contract MainnetAddresses {
    address public constant PT_sUSDE_27NOV2025 = 0xe6A934089BBEe34F832060CE98848359883749B3;
    address public constant PT_cUSDO_20NOV2025 = 0xB10DA2F9147f9cf2B8826877Cd0c95c18A0f42dc;
    address public constant PT_wstUSR_29JAN2026 = 0xfCeEB7586bab730fA400A5BF3FcF298d0DB4c7e7;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address public constant cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    struct ChainlinkPriceFeedParams {
        address aggregator;
        uint256 stalePriceInterval;
    }

    struct UniswapV3PriceFeedParams {
        address pool;
        uint32 twapWindow;
        uint32 averageBlockTime;
    }

    ChainlinkPriceFeedParams CHAINLINK_WBTC_BTC =
        ChainlinkPriceFeedParams(0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23, 86400);
    ChainlinkPriceFeedParams CHAINLINK_BTC_USD =
        ChainlinkPriceFeedParams(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, 3600);
    ChainlinkPriceFeedParams CHAINLINK_cbBTC_USD =
        ChainlinkPriceFeedParams(0x2665701293fCbEB223D11A08D826563EDcCE423A, 86400);
    ChainlinkPriceFeedParams CHAINLINK_ETH_USD =
        ChainlinkPriceFeedParams(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 3600);
    ChainlinkPriceFeedParams CHAINLINK_stETH_USD =
        ChainlinkPriceFeedParams(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8, 3600);
    ChainlinkPriceFeedParams CHAINLINK_weETH_ETH =
        ChainlinkPriceFeedParams(0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22, 86400);
    ChainlinkPriceFeedParams CHAINLINK_cbETH_ETH =
        ChainlinkPriceFeedParams(0xF017fcB346A1885194689bA23Eff2fE6fA5C483b, 86400);
    ChainlinkPriceFeedParams CHAINLINK_USDC_USD =
        ChainlinkPriceFeedParams(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6, 82800);

    UniswapV3PriceFeedParams UNISWAP_V3_WBTC_USDC =
        UniswapV3PriceFeedParams(0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35, 30 minutes, 12 seconds);
    UniswapV3PriceFeedParams UNISWAP_V3_USDC_cbBTC =
        UniswapV3PriceFeedParams(0x54E58c986818903d2d86dAfE03f5F5E6C2cA6710, 30 minutes, 12 seconds);
    UniswapV3PriceFeedParams UNISWAP_V3_USDC_WETH =
        UniswapV3PriceFeedParams(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640, 30 minutes, 12 seconds);
    UniswapV3PriceFeedParams UNISWAP_V3_wstETH_WETH =
        UniswapV3PriceFeedParams(0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa, 30 minutes, 12 seconds);
    UniswapV3PriceFeedParams UNISWAP_V3_WETH_weETH =
        UniswapV3PriceFeedParams(0x202A6012894Ae5c288eA824cbc8A9bfb26A49b93, 30 minutes, 12 seconds);
    UniswapV3PriceFeedParams UNISWAP_V3_cbETH_WETH =
        UniswapV3PriceFeedParams(0x840DEEef2f115Cf50DA625F7368C24af6fE74410, 30 minutes, 12 seconds);

    address public constant MORPHO_WBTC_USDC_ORACLE = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
    address public constant MORPHO_cbBTC_USDC_ORACLE = 0xA6D6950c9F177F1De7f7757FB33539e3Ec60182a;

    address public constant MORPHO_wstETH_USDC_ORACLE = 0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2;
}
