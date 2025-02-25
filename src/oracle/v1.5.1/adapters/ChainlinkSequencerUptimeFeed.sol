// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

/// @title ChainlinkSequencerUptimeFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev See https://docs.chain.link/data-feeds/l2-sequencer-feeds
///      The sequencer is down if if `startedAt` is 0 (only on Arbitrum) or if `answer` is 1
contract ChainlinkSequencerUptimeFeed {
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /* solhint-disable */
    AggregatorV3Interface public immutable sequencerUptimeFeed;
    /* solhint-enable */

    constructor(AggregatorV3Interface _sequencerUptimeFeed) {
        // the _sequencerUptimeFeed can be null for unsupported networks
        sequencerUptimeFeed = _sequencerUptimeFeed;
    }

    /// @notice Validates that the sequencer is up
    /// @dev If the sequencer is down, reverts with the error message
    function validateSequencerIsUp() external view {
        if (address(sequencerUptimeFeed) != address(0)) {
            // slither-disable-next-line unused-return
            (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

            if (startedAt == 0 || answer == 1) {
                // sequencer is down
                revert Errors.SEQUENCER_DOWN();
            }

            if (block.timestamp - startedAt <= GRACE_PERIOD_TIME) {
                // time since up
                revert Errors.GRACE_PERIOD_NOT_OVER();
            }
        }
    }
}
