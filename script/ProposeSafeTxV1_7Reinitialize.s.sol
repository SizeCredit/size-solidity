// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {IMultiSendCallOnly} from "@script/interfaces/IMultiSendCallOnly.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";
import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {Networks} from "@script/Networks.sol";

import {ISafe} from "@script/interfaces/ISafe.sol";
import {PAUSER_ROLE} from "@src/factory/interfaces/ISizeFactory.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

contract ProposeSafeTxV1_7ReinitializeScript is BaseScript, Networks {
    string private network;
    ISizeFactory private sizeFactory;
    IMultiSendCallOnly private multisendcallonly;
    Size internal sizeV1_7;
    SizeFactory internal sizeFactoryV1_7;

    modifier parseEnv() {
        network = vm.envString("NETWORK");
        sizeFactory = ISizeFactory(vm.envAddress("SIZE_FACTORY"));
        sizeV1_7 = Size(vm.envAddress("SIZE_V1_7"));
        sizeFactoryV1_7 = SizeFactory(vm.envAddress("SIZE_FACTORY_V1_7"));
        _;
    }

    function getV1_7ReinitializeData(ISizeFactory _sizeFactory, IMultiSendCallOnly _multiSendCallOnly)
        internal
        view
        returns (address _to, bytes memory _data)
    {
        ISize[] memory markets = _sizeFactory.getMarkets();
        bytes1 operation = bytes1(0x00);
        uint256 value = 0;
        uint256 dataLength = 0;

        _to = address(_multiSendCallOnly);

        console.log("sizeV1_7: %s", address(sizeV1_7));
        console.log("sizeFactoryV1_7: %s", address(sizeFactoryV1_7));

        bytes memory data;
        bytes memory transaction;

        // SizeFactory.upgradeToAndCall(SizeFactoryV1_7, reinitialize())
        data = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (address(sizeFactoryV1_7), abi.encodeCall(ISizeFactoryV1_7.reinitialize, ()))
        );
        dataLength = data.length;
        transaction = abi.encodePacked(operation, address(_sizeFactory), value, dataLength, data);
        _data = abi.encodePacked(_data, transaction);

        // SizeFactory.setSizeImplementation
        data = abi.encodeCall(ISizeFactory.setSizeImplementation, (address(sizeV1_7)));
        dataLength = data.length;
        transaction = abi.encodePacked(operation, address(_sizeFactory), value, dataLength, data);
        _data = abi.encodePacked(_data, transaction);

        // SizeFactory.grantRole(PAUSER_ROLE, _) for all multisig owners
        address multisig = OwnableUpgradeable(address(_sizeFactory)).owner();
        address[] memory owners = ISafe(multisig).getOwners();
        bytes[] memory grantRoles = new bytes[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            grantRoles[i] = abi.encodeCall(AccessControlUpgradeable.grantRole, (PAUSER_ROLE, owners[i]));
        }
        bytes memory multicall = abi.encodeCall(MulticallUpgradeable.multicall, (grantRoles));

        data = multicall;
        dataLength = data.length;
        transaction = abi.encodePacked(operation, address(_sizeFactory), value, dataLength, data);
        _data = abi.encodePacked(_data, transaction);

        // Size.upgradeToAndCall(SizeV1_7, reinitialize(SizeFactory)) for all markets
        for (uint256 i = 0; i < markets.length; i++) {
            data = abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (address(sizeV1_7), abi.encodeCall(ISizeV1_7.reinitialize, (_sizeFactory)))
            );
            dataLength = data.length;
            transaction = abi.encodePacked(operation, address(markets[i]), value, dataLength, data);
            _data = abi.encodePacked(_data, transaction);
        }
    }

    function run() external parseEnv ignoreGas {
        multisendcallonly = multiSendCallOnly(network);
        (address to, bytes memory multisendcallonlyData) = getV1_7ReinitializeData(sizeFactory, multisendcallonly);
        bytes memory data = abi.encodeCall(IMultiSendCallOnly.multiSend, (multisendcallonlyData));
        console.log("to: %s", to);
        console.log("data:");
        console.logBytes(data);

        string[] memory args = new string[](4);
        args[0] = "node";
        args[1] = "script/proposeTransaction.js";
        args[2] = vm.toString(to);
        args[3] = vm.toString(data);
        vm.ffi(args);
    }
}
