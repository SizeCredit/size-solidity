// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {Contract, NetworkConfiguration, Networks} from "@script/Networks.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IMorphoChainlinkOracleV2} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2.sol";
import {IMorphoChainlinkOracleV2Factory} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2Factory.sol";

contract DeployMorphoChainlinkOracleV2Script is BaseScript, Networks, Deploy {
    function setUp() public {}

    function run() public broadcast {
        console.log("[MorphoChainlinkOracleV2] deploying...");

        IMorphoChainlinkOracleV2Factory morphoChainlinkOracleV2Factory =
            IMorphoChainlinkOracleV2Factory(addresses[block.chainid][Contract.MORPHO_CHAINLINK_ORACLE_V2_FACTORY]);

        console.log("[MorphoChainlinkOracleV2] morphoChainlinkOracleV2Factory", address(morphoChainlinkOracleV2Factory));

        /*
        Reference:
        https://etherscan.io/tx/0x16c56247f91f4541c1cb284c2a4ff9ad9a3eafe2a41846e0ff14a902b2e8766a
        #	Name	Type	Data
        0	baseVault	address 0x0000000000000000000000000000000000000000
        1	baseVaultConversionSample	uint256 1
        2	baseFeed1	address 0x51EFC18301789beaF5F0e5D4C72e4FACE72E3658
        3	baseFeed2	address 0x0000000000000000000000000000000000000000
        4	baseTokenDecimals	uint256 18
        5	quoteVault	address 0x0000000000000000000000000000000000000000
        6	quoteVaultConversionSample	uint256 1
        7	quoteFeed1	address 0x0000000000000000000000000000000000000000
        8	quoteFeed2	address 0x0000000000000000000000000000000000000000
        9	quoteTokenDecimals	uint256 6
        10	salt	bytes32 0x0000000000000000000000000000000000000000000000000000000000000000
        */

        morphoChainlinkOracleV2Factory.createMorphoChainlinkOracleV2(
            address(0),
            1,
            AggregatorV3Interface(0xB608A1584322e68C401129E1E8775777c43cb6F7),
            AggregatorV3Interface(0x0000000000000000000000000000000000000000),
            18,
            address(0),
            1,
            AggregatorV3Interface(0x0000000000000000000000000000000000000000),
            AggregatorV3Interface(0x0000000000000000000000000000000000000000),
            6,
            bytes32(0)
        );

        console.log("[MorphoChainlinkOracleV2] done");
    }
}
