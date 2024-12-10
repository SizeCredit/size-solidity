// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPriceFeedV1_5} from "@src/oracle/deprecated/IPriceFeedV1_5.sol";

import {ChainlinkPriceFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkPriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/v1.5.1/adapters/UniswapV3PriceFeed.sol";

/// @title IPriceFeedV1_5_1
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface IPriceFeedV1_5_1 is IPriceFeedV1_5 {
    function chainlinkSequencerUptimeFeed() external view returns (ChainlinkSequencerUptimeFeed);
    function chainlinkPriceFeed() external view returns (ChainlinkPriceFeed);
    function uniswapV3PriceFeed() external view returns (UniswapV3PriceFeed);
}
