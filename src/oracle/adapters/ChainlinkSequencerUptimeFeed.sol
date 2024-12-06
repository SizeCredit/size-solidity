// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title ChainlinkSequencerUptimeFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev See https://docs.chain.link/data-feeds/l2-sequencer-feeds
contract ChainlinkSequencerUptimeFeed {
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /* solhint-disable */
    AggregatorV3Interface public immutable sequencerUptimeFeed;
    /* solhint-enable */

    constructor(
        address _sequencerUptimeFeed
    ) {
        // the _sequencerUptimeFeed can be null for unsupported networks
        
        sequencerUptimeFeed = AggregatorV3Interface(_sequencerUptimeFeed);
    }

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