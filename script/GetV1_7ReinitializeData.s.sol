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

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

contract GetV1_7ReinitializeDataScript is BaseScript {
    string private network;
    ISizeFactory private sizeFactory;
    IMultiSendCallOnly private multiSendCallOnly;

    modifier parseEnv() {
        network = vm.envString("NETWORK");
        sizeFactory = ISizeFactory(vm.envAddress("SIZE_FACTORY"));
        multiSendCallOnly = IMultiSendCallOnly(vm.envAddress("MULTI_SEND_CALL_ONLY"));
        _;
    }

    function getV1_7ReinitializeData(ISizeFactory _sizeFactory, IMultiSendCallOnly _multiSendCallOnly)
        internal
        returns (address _to, bytes memory _data)
    {
        ISize[] memory markets = _sizeFactory.getMarkets();
        bytes1 operation = bytes1(uint8(0x00));
        uint256 value = 0;
        uint256 dataLength = 0;

        _to = address(_multiSendCallOnly);

        Size sizeV1_7 = new Size();
        SizeFactory sizeFactoryV1_7 = new SizeFactory();

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
        (address to, bytes memory data) = getV1_7ReinitializeData(sizeFactory, multiSendCallOnly);
        // data is the `transaction` parameter of the `multiSend` function
        exportV1_7ReinitializeData(network, to, data);
    }
}
