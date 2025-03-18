// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseScript} from "@script/BaseScript.sol";
import {IMultiSendCallOnly} from "@script/interfaces/IMultiSendCallOnly.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {UpdateConfigParams} from "@src/market/libraries/actions/UpdateConfig.sol";

import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Networks} from "@script/Networks.sol";
import {console} from "forge-std/console.sol";

contract GetUpdateConfigDataScript is BaseScript, Networks {
    string private network;
    ISizeFactory private sizeFactory;

    modifier parseEnv() {
        network = vm.envString("NETWORK");
        sizeFactory = ISizeFactory(vm.envAddress("SIZE_FACTORY"));
        _;
    }

    function getUpdateConfigData(ISizeFactory _sizeFactory, IMultiSendCallOnly _multiSendCallOnly)
        internal
        view
        returns (address _to, bytes memory _data)
    {
        ISize[] memory markets = _sizeFactory.getMarkets();
        bytes1 operation = bytes1(0x00);
        uint256 value = 0;
        uint256 dataLength = 0;

        _to = address(_multiSendCallOnly);

        bytes memory data;
        bytes memory transaction;

        string memory updateConfigKey = "swapFeeAPR";
        uint256 updateConfigValue = 0;

        uint256[] memory swapFeeAPRs = new uint256[](markets.length);

        // Size.updateConfig(key, value) for all markets
        for (uint256 i = 0; i < markets.length; i++) {
            swapFeeAPRs[i] = markets[i].feeConfig().swapFeeAPR;
            console.log("swapFeeAPRs[%s]: %s", i, swapFeeAPRs[i]);

            data = abi.encodeCall(
                Size.updateConfig, (UpdateConfigParams({key: updateConfigKey, value: updateConfigValue}))
            );
            dataLength = data.length;
            transaction = abi.encodePacked(operation, address(markets[i]), value, dataLength, data);
            _data = abi.encodePacked(_data, transaction);
        }
    }

    function run() external parseEnv ignoreGas {
        IMultiSendCallOnly multisendcallonly = multiSendCallOnly(network);
        // data is the `transaction` parameter of the `multiSend` function
        (address to, bytes memory data) = getUpdateConfigData(sizeFactory, multisendcallonly);
        // full data is the full MultiSendCallOnly calldata
        bytes memory fulldata = abi.encodeCall(IMultiSendCallOnly.multiSend, (data));
        console.log("to (multisend): %s", to);
        console.log("data (full):");
        console.logBytes(fulldata);
    }
}
