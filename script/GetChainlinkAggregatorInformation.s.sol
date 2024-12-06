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

    function run() public {
        uint256 deploymentBlock = 20637165;
        address aggregator = 0x52A12E019826C53B1f7Fd3E6D9546c0935377B95;

        bytes32[] memory topics = new bytes32[](1);
        topics[0] = NewRound.selector;

        uint256 toBlock = vm.getBlockNumber();
        uint256 fromBlock = deploymentBlock;
        uint256 batchSize = 100_000;

        Vm.EthGetLogs[] memory logs;

        while (fromBlock < toBlock) {
            uint256 endBlock = (fromBlock + batchSize > toBlock) ? toBlock : fromBlock + batchSize;

            console.log("block range: %s - %s", fromBlock, endBlock);

            logs = vm.eth_getLogs(fromBlock, endBlock, aggregator, topics);

            for (uint256 j = 0; j < logs.length; j++) {
                Vm.EthGetLogs memory log = logs[j];
                uint64 blockNumber = log.blockNumber;
                console.log("blockNumber: %s", blockNumber);
            }

            fromBlock = endBlock + 1;
        }
    }
}
