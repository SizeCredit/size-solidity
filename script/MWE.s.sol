// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {Contract, Networks} from "@script/Networks.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeAdmin} from "@src/market/interfaces/ISizeAdmin.sol";
import {UpdateConfigParams} from "@src/market/libraries/actions/UpdateConfig.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PendleSparkLinearDiscountOracle} from "@pendle/contracts/oracles/internal/PendleSparkLinearDiscountOracle.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeedPendleChainlink} from "@src/oracle/v1.7.1/PriceFeedPendleChainlink.sol";

import {HTTP} from "@safe-utils/../lib/solidity-http/src/HTTP.sol";

import {console} from "forge-std/console.sol";

contract MWEScript is BaseScript, Networks {
    using HTTP for *;

    HTTP.Client http;
    ISizeFactory sizeFactory;

    modifier parseEnv() {
        sizeFactory = ISizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);
        http.initialize();
        _;
    }

    function run() external parseEnv {
        ISize market = sizeFactory.getMarket(1);
        IPriceFeed oldPriceFeed = IPriceFeed(market.oracle().priceFeed);
        uint256 oldPrice = oldPriceFeed.getPrice();
        console.log("old Price Feed", address(oldPriceFeed));

        console.log("oldPrice", oldPrice);

        (
            ,
            PendleSparkLinearDiscountOracle pendleOracle,
            AggregatorV3Interface underlyingChainlinkOracle,
            AggregatorV3Interface quoteChainlinkOracle,
            uint256 underlyingStalePriceInterval,
            uint256 quoteStalePriceInterval,
            ,
        ) = priceFeedPendleChainlink29May2025UsdcMainnet();

        PriceFeedPendleChainlink newPriceFeed = new PriceFeedPendleChainlink(
            pendleOracle,
            underlyingChainlinkOracle,
            quoteChainlinkOracle,
            underlyingStalePriceInterval,
            quoteStalePriceInterval
        );

        console.log("new Price Feed", address(newPriceFeed));

        string memory body = vm.serializeAddress(".", "priceFeed", address(newPriceFeed));

        HTTP.Response memory res = http.initialize("https://httpbin.org/post").POST().withBody(body).request();
        require(res.status == 200, "Failed to propose safe tx");
    }
}
