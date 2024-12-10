// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {console} from "forge-std/Script.sol";

import {Vm} from "forge-std/Vm.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {Networks} from "@script/Networks.sol";

contract GetChainlinkAggregatorInformationScript is BaseScript, Networks, Deploy {
    EnumerableMap.AddressToUintMap addresses;

    function setUp() public {}

    event NewRound(uint256 roundId, address startedBy, uint256 startedAt);

    function run() public ignoreGas {
        uint256 deploymentBlock = 17147278;
        address aggregator = 0x330eC3210511cC8f5A87A737A08905092e033AF3;

        bytes32[] memory topics = new bytes32[](1);
        topics[0] = NewRound.selector;

        uint256 toBlock = vm.getBlockNumber();
        uint256 fromBlock = deploymentBlock;
        uint256 batchSize = 100_000;

        Vm.EthGetLogs[] memory logs;

        while (fromBlock < toBlock) {
            uint256 endBlock = (fromBlock + batchSize > toBlock) ? toBlock : fromBlock + batchSize;

            logs = vm.eth_getLogs(fromBlock, endBlock, aggregator, topics);

            for (uint256 j = 0; j < logs.length; j++) {
                Vm.EthGetLogs memory log = logs[j];
                uint64 blockNumber = log.blockNumber;
                console.log("%s", blockNumber);
            }

            fromBlock = endBlock + 1;
        }
    }
}
