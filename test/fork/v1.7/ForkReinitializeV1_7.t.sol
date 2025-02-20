// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";
import {ISizeFactoryV1_7} from "@src/v1.5/interfaces/ISizeFactoryV1_7.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Networks} from "@script/Networks.sol";
import {IMultiSendCallOnly} from "@script/interfaces/IMultiSendCallOnly.sol";

import {GetV1_7ReinitializeDataScript} from "@script/GetV1_7ReinitializeData.s.sol";

import {ISafe} from "@script/interfaces/ISafe.sol";
import {VERSION} from "@src/interfaces/ISize.sol";
import {SafeUtils} from "@test/SafeUtils.sol";

import {ActionsBitmap} from "@src/v1.5/libraries/Authorization.sol";

contract ForkReinitializeV1_7Test is ForkTest, GetV1_7ReinitializeDataScript, Networks, SafeUtils {
    struct Vars {
        ISizeFactory sizeFactory;
        IMultiSendCallOnly multiSendCallOnly;
        address owner;
    }

    function _getV1_7ReinitializeAddresses(string memory network, uint256 blockNumber)
        private
        returns (Vars memory vars)
    {
        vm.createSelectFork(network, blockNumber);
        vars.sizeFactory = importSizeFactory(string.concat(network, "-size-factory"));
        vars.multiSendCallOnly = multiSendCallOnly(network);
        vars.owner = OwnableUpgradeable(address(vars.sizeFactory)).owner();

        vm.label(address(vars.sizeFactory), "SizeFactory");
        vm.label(address(vars.multiSendCallOnly), "MultiSendCallOnly");
        vm.label(vars.owner, "owner");
    }

    function _testFork_ForkReinitializeV1_7_reinitialize(string memory network, uint256 blockNumber) private {
        Vars memory vars = _getV1_7ReinitializeAddresses(network, blockNumber);

        (address to, bytes memory data) = getV1_7ReinitializeData(vars.sizeFactory, vars.multiSendCallOnly);

        // pre-checks
        ISize[] memory markets = vars.sizeFactory.getMarkets();
        address[] memory borrowATokenV1_5 = new address[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            ISize market = markets[i];
            borrowATokenV1_5[i] = address(market.data().borrowAToken);
            assertEq(market.version(), "v1.6.1");
        }
        (bool success,) = address(vars.sizeFactory).call(
            abi.encodeWithSelector(ISizeFactoryV1_7.setAuthorization.selector, address(0x1000), 1)
        );
        assertTrue(!success);
        assertTrue(!Strings.equal(VERSION, "v1.6.1"));

        console.log("to", to);
        console.logBytes(data);

        _simulateSafeMultiSendCallOnly(ISafe(vars.owner), to, data);

        // post-checks
        for (uint256 i = 0; i < markets.length; i++) {
            ISize market = markets[i];
            assertEq(address(market.data().borrowAToken), borrowATokenV1_5[i]);
            assertEq(address(market.sizeFactory()), address(vars.sizeFactory));
            assertEq(market.version(), VERSION);
        }
        (success,) = address(vars.sizeFactory).call(
            abi.encodeWithSelector(ISizeFactoryV1_7.setAuthorization.selector, address(0x1000), 1)
        );
        assertTrue(success);
    }

    function testFork_ForkReinitializeV1_7_reinitialize() public {
        // 2025-02-18T19:25Z
        _testFork_ForkReinitializeV1_7_reinitialize("mainnet", 21875339);
        _testFork_ForkReinitializeV1_7_reinitialize("base-production", 26558714);
    }
}
