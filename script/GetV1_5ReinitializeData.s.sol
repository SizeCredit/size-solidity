// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {NonTransferrableScaledTokenV1_2} from "@deprecated/token/NonTransferrableScaledTokenV1_2.sol";
import {Networks} from "@script/Networks.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GetV1_5ReinitializeDataScript is BaseScript, Networks {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private addressesWethUsdc;
    EnumerableMap.AddressToUintMap private addressesCbbtcUsdc;
    ISizeFactory private sizeFactory;

    modifier parseEnv() {
        sizeFactory = ISizeFactory(vm.envAddress("SIZE_FACTORY"));
        _;
    }

    function run() external parseEnv ignoreGas {
        string[2] memory markets = block.chainid == BASE_MAINNET
            ? ["base-production-weth-usdc", "base-production-cbbtc-usdc"]
            : ["base-sepolia-weth-usdc", "base-sepolia-link-usdc"];
        uint256[2] memory deploymentBlocks = block.chainid == BASE_MAINNET
            ? [uint256(17147278), uint256(20637165)]
            : [uint256(18082649), uint256(18082796)];
        ISize market0 = sizeFactory.getMarket(0);
        address borrowTokenVault = address(market0.data().borrowTokenVault);

        console.log("GetV1_5ReinitializeData...");

        for (uint256 i = 0; i < markets.length; i++) {
            (ISize market,,) = importDeployments(markets[i]);
            EnumerableMap.AddressToUintMap storage addresses =
                Strings.equal(markets[i], markets[0]) ? addressesWethUsdc : addressesCbbtcUsdc;

            // We use .data().borrowTokenVault here since, before the migration, it points to the V1_2 token.
            // After the migration, it will point to the V1_5 token
            NonTransferrableScaledTokenV1_2 borrowATokenV1_2 =
                NonTransferrableScaledTokenV1_2(address(market.data().borrowTokenVault));

            bytes32[] memory topics = new bytes32[](1);
            topics[0] = IERC20.Transfer.selector;

            uint256 toBlock = vm.getBlockNumber();
            uint256 fromBlock = deploymentBlocks[i];
            uint256 batchSize = 100_000;

            Vm.EthGetLogs[] memory logs;

            while (fromBlock < toBlock) {
                uint256 endBlock = (fromBlock + batchSize > toBlock) ? toBlock : fromBlock + batchSize;

                console.log("block range: %s - %s", fromBlock, endBlock);

                logs = vm.eth_getLogs(fromBlock, endBlock, address(borrowATokenV1_2), topics);

                for (uint256 j = 0; j < logs.length; j++) {
                    Vm.EthGetLogs memory log = logs[j];
                    address to = address(uint160(uint256(log.topics[2])));
                    if (!addresses.contains(to)) {
                        uint256 balance = borrowATokenV1_2.balanceOf(to);
                        if (balance > 0) {
                            addresses.set(to, balance);
                        }
                    }
                }

                fromBlock = endBlock + 1;
            }

            console.log("Market: %s, Users: %s", markets[i], addresses.length());

            exportV1_5ReinitializeData(markets[i], addresses, toBlock, borrowTokenVault);
        }
    }
}
