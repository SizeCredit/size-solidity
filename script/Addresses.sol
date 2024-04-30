// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

struct Contracts {
    address weth;
    address usdc;
    address variablePool;
    address wethAggregator;
    address usdcAggregator;
}

abstract contract Addresses {
    error InvalidChain(string chain);

    function addresses(string memory chain) public pure returns (Contracts memory) {
        if (Strings.equal(chain, "sepolia")) {
            return Contracts({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
                variablePool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951,
                wethAggregator: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                usdcAggregator: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
            });
        } else if (Strings.equal(chain, "sepolia-mocks")) {
            return Contracts({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
                variablePool: address(0),
                wethAggregator: address(0),
                usdcAggregator: address(0)
            });
        } else if (Strings.equal(chain, "tenderly-mainnet-fork")) {
            return Contracts({
                weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                variablePool: 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
                wethAggregator: address(0),
                usdcAggregator: address(0)
            });
        } else if (Strings.equal(chain, "tenderly-base-fork")) {
            return Contracts({
                weth: 0x4200000000000000000000000000000000000006,
                usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                variablePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
                wethAggregator: address(0),
                usdcAggregator: address(0)
            });
        } else {
            revert InvalidChain(chain);
        }
    }
}
