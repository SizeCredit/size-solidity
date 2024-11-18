// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

struct NetworkConfiguration {
    address weth;
    address underlyingCollateralToken;
    address underlyingBorrowToken;
    address variablePool;
    address underlyingCollateralTokenAggregator;
    address underlyingBorrowTokenAggregator;
    address sequencerUptimeFeed;
    uint256 underlyingCollateralTokenHeartbeat;
    uint256 underlyingBorrowTokenHeartbeat;
    uint256 fragmentationFee;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 borrowATokenCap;
}

abstract contract Networks {
    error InvalidNetworkConfiguration(string networkConfiguration);

    function params(string memory networkConfiguration) public pure returns (NetworkConfiguration memory) {
        if (Strings.equal(networkConfiguration, "sepolia-mocks")) {
            return NetworkConfiguration({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                underlyingCollateralToken: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                underlyingBorrowToken: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
                variablePool: address(0),
                underlyingCollateralTokenAggregator: address(0),
                underlyingBorrowTokenAggregator: address(0),
                sequencerUptimeFeed: address(0),
                underlyingCollateralTokenHeartbeat: 0,
                underlyingBorrowTokenHeartbeat: 0,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "base-sepolia-weth-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0x4200000000000000000000000000000000000006,
                underlyingBorrowToken: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
                variablePool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b,
                underlyingCollateralTokenAggregator: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1,
                underlyingBorrowTokenAggregator: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165,
                sequencerUptimeFeed: address(0),
                underlyingCollateralTokenHeartbeat: 1200 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "base-sepolia-link-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
                underlyingBorrowToken: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
                variablePool: 0x07eA79F68B2B3df564D0A34F8e19D9B1e339814b,
                underlyingCollateralTokenAggregator: 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61,
                underlyingBorrowTokenAggregator: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165,
                sequencerUptimeFeed: address(0),
                underlyingCollateralTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "mainnet-production")) {
            return NetworkConfiguration({
                weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                underlyingCollateralToken: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                underlyingBorrowToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                variablePool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
                underlyingCollateralTokenAggregator: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
                underlyingBorrowTokenAggregator: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6,
                sequencerUptimeFeed: address(0),
                underlyingCollateralTokenHeartbeat: 3600 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "base-mocks")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0x4200000000000000000000000000000000000006,
                underlyingBorrowToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: address(0),
                underlyingCollateralTokenAggregator: address(0),
                underlyingBorrowTokenAggregator: address(0),
                sequencerUptimeFeed: address(0),
                underlyingCollateralTokenHeartbeat: 0,
                underlyingBorrowTokenHeartbeat: 0,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "base-production-weth-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0x4200000000000000000000000000000000000006,
                underlyingBorrowToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                underlyingCollateralTokenAggregator: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
                underlyingBorrowTokenAggregator: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
                sequencerUptimeFeed: 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433,
                underlyingCollateralTokenHeartbeat: 1200 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "base-production-cbbtc-usdc")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
                underlyingBorrowToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                underlyingCollateralTokenAggregator: 0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D,
                underlyingBorrowTokenAggregator: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
                sequencerUptimeFeed: 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433,
                underlyingCollateralTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(networkConfiguration, "base-production-wsteth-weth")) {
            return NetworkConfiguration({
                weth: 0x4200000000000000000000000000000000000006,
                underlyingCollateralToken: 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452,
                underlyingBorrowToken: 0x4200000000000000000000000000000000000006,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                underlyingCollateralTokenAggregator: 0x43a5C292A453A3bF3606fa856197f09D7B74251a,
                underlyingBorrowTokenAggregator: 0x43a5C292A453A3bF3606fa856197f09D7B74251a,
                sequencerUptimeFeed: 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433,
                underlyingCollateralTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 0.0005e18,
                crOpening: 1.3e18,
                crLiquidation: 1.1e18,
                minimumCreditBorrowAToken: 0.005e18,
                borrowATokenCap: 500e18
            });
        } else if (Strings.equal(networkConfiguration, "arbitrum-production-susde-usdc")) {
            return NetworkConfiguration({
                weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
                underlyingCollateralToken: 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2,
                underlyingBorrowToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
                variablePool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
                underlyingCollateralTokenAggregator: 0xf2215b9c35b1697B5f47e407c917a40D055E68d7,
                underlyingBorrowTokenAggregator: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
                sequencerUptimeFeed: 0xFdB631F5EE196F0ed6FAa767959853A9F217697D,
                underlyingCollateralTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                underlyingBorrowTokenHeartbeat: 86400 * 1.1e18 / 1e18,
                fragmentationFee: 1e6,
                crOpening: 1.3e18,
                crLiquidation: 1.1e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else {
            revert InvalidNetworkConfiguration(networkConfiguration);
        }
    }
}
