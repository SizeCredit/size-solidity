// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

struct NetworkParams {
    address weth;
    address usdc;
    address variablePool;
    address wethAggregator;
    address usdcAggregator;
    address sequencerUptimeFeed;
    uint256 wethHeartbeat;
    uint256 usdcHeartbeat;
}

abstract contract Networks {
    error InvalidChain(string chain);

    function params(string memory chain) public pure returns (NetworkParams memory) {
        if (Strings.equal(chain, "sepolia")) {
            return NetworkParams({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
                variablePool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951,
                wethAggregator: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                usdcAggregator: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
                sequencerUptimeFeed: address(0),
                wethHeartbeat: type(uint256).max,
                usdcHeartbeat: type(uint256).max
            });
        } else if (Strings.equal(chain, "sepolia-mocks")) {
            return NetworkParams({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
                variablePool: address(0),
                wethAggregator: address(0),
                usdcAggregator: address(0),
                sequencerUptimeFeed: address(0),
                wethHeartbeat: 0,
                usdcHeartbeat: 0
            });
        } else {
            revert InvalidChain(chain);
        }
    }
}
