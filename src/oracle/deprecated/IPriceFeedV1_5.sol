// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title IPriceFeedV1_5
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Getters from previous PriceFeed implementation. Maintained for backwards compatibility.
interface IPriceFeedV1_5 is IPriceFeed {
    function base() external view returns (AggregatorV3Interface);
    function quote() external view returns (AggregatorV3Interface);
    function baseStalePriceInterval() external view returns (uint256);
    function quoteStalePriceInterval() external view returns (uint256);
}
