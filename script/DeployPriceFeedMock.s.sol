// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "forge-std/Script.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

contract DeployPriceFeedMockScript is BaseScript {
    function setUp() public {}

    function run() public broadcast {
        console.log("[PriceFeedMock] deploying...");

        PriceFeedMock priceFeedMock = new PriceFeedMock(msg.sender);

        console.log("[PriceFeedMock] priceFeed", address(priceFeedMock));

        console.log("[PriceFeedMock] done");
    }
}
