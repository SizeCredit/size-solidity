// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title IPriceFeedV1_5_3
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface IPriceFeedV1_5_3 is IPriceFeed {
    /// @notice Returns the description of the price feed
    function description() external view returns (string memory);
}
