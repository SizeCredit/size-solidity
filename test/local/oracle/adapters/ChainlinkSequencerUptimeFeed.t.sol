// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

contract ChainlinkSequencerUptimeFeedTest is Test, AssertsHelper {
    MockV3Aggregator public sequencerUptimeFeed;
    ChainlinkSequencerUptimeFeed public chainlinkSequencerUptimeFeed;
    int256 private constant SEQUENCER_UP = 0;
    int256 private constant SEQUENCER_DOWN = 1;

    function setUp() public {
        sequencerUptimeFeed = new MockV3Aggregator(0, SEQUENCER_UP);
        vm.warp(block.timestamp + 1 days);
        chainlinkSequencerUptimeFeed = new ChainlinkSequencerUptimeFeed(sequencerUptimeFeed);
    }

    function test_ChainlinkSequencerUptimeFeed_validation() public {
        // do not revert if sequencerUptimeFeed is null
        new ChainlinkSequencerUptimeFeed(AggregatorV3Interface(address(0)));
    }

    function test_ChainlinkSequencerUptimeFeed_validateSequencerIsUp_reverts_sequencer_down() public {
        uint256 updatedAt = block.timestamp;
        vm.warp(updatedAt + 365 days);

        sequencerUptimeFeed.updateAnswer(1);
        vm.expectRevert(abi.encodeWithSelector(Errors.SEQUENCER_DOWN.selector));
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();

        sequencerUptimeFeed.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.GRACE_PERIOD_NOT_OVER.selector));
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();

        vm.warp(block.timestamp + 3600 + 1);
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();
    }
}
