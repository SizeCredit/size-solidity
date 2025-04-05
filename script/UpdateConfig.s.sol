// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseScript} from "@script/BaseScript.sol";
import {Size} from "@src/market/Size.sol";
import {UpdateConfigParams} from "@src/market/libraries/actions/UpdateConfig.sol";
import {console2 as console} from "forge-std/console2.sol";

contract UpdateConfigScript is BaseScript {
    function run() external broadcast {
        console.log("UpdateConfig...");
        address sizeContractAddress = vm.envAddress("SIZE_ADDRESS");
        string memory key = "priceFeed";
        uint256 value = uint256(uint160(vm.envAddress("PRICE_FEED")));

        Size size = Size(payable(sizeContractAddress));

        size.updateConfig(UpdateConfigParams({key: key, value: value}));
    }
}
