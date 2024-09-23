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
    error InvalidChain(string chain);

    function params(string memory chain) public pure returns (NetworkConfiguration memory) {
        if (Strings.equal(chain, "sepolia")) {
            return NetworkConfiguration({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                underlyingCollateralToken: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                underlyingBorrowToken: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
                variablePool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951,
                underlyingCollateralTokenAggregator: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                underlyingBorrowTokenAggregator: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
                sequencerUptimeFeed: address(0),
                underlyingCollateralTokenHeartbeat: type(uint256).max,
                underlyingBorrowTokenHeartbeat: type(uint256).max,
                fragmentationFee: 1e6,
                crOpening: 1.5e18,
                crLiquidation: 1.3e18,
                minimumCreditBorrowAToken: 10e6,
                borrowATokenCap: 1_000_000e6
            });
        } else if (Strings.equal(chain, "sepolia-mocks")) {
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
        } else if (Strings.equal(chain, "base-sepolia")) {
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
        } else if (Strings.equal(chain, "mainnet-production")) {
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
        } else if (Strings.equal(chain, "base-production")) {
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
        } else if (Strings.equal(chain, "base-mocks")) {
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
        } else if (Strings.equal(chain, "base-production-cbbtc-usdc")) {
            // TODO
            revert InvalidChain(chain);
        } else if (Strings.equal(chain, "base-production-wsteth-eth")) {
            // TODO
            revert InvalidChain(chain);
        } else if (Strings.equal(chain, "arbitrum-production-susde-usdc")) {
            // TODO
            revert InvalidChain(chain);
        } else {
            revert InvalidChain(chain);
        }
    }
}
