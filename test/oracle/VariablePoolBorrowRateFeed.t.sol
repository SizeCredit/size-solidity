// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {VariablePoolBorrowRateFeed} from "@src/oracle/VariablePoolBorrowRateFeed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract VariablePoolBorrowRateFeedTest is Test, AssertsHelper {
    VariablePoolBorrowRateFeed public variablePoolBorrowRateFeed;

    function setUp() public {
        variablePoolBorrowRateFeed = new VariablePoolBorrowRateFeed(address(this), 1 hours, 0.0456e18);
    }

    function test_VariablePoolBorrowRateFeed_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new VariablePoolBorrowRateFeed(address(0), 1 hours, 0.08e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_STALE_RATE.selector));
        new VariablePoolBorrowRateFeed(address(this), 0, 0.05e18);
    }

    function testFuzz_VariablePoolBorrowRateFeed_setVariableBorrowRate(uint128 rate) public {
        variablePoolBorrowRateFeed.setVariableBorrowRate(rate);
        assertEq(variablePoolBorrowRateFeed.getVariableBorrowRate(), rate);
    }

    function testFuzz_VariablePoolBorrowRateFeed_setStaleRateInterval(uint64 interval) public {
        variablePoolBorrowRateFeed.setVariableBorrowRate(123e18);
        variablePoolBorrowRateFeed.setStaleRateInterval(interval);
        assertEq(variablePoolBorrowRateFeed.getVariableBorrowRate(), 123e18);
        vm.warp(block.timestamp + interval + 1);
        try variablePoolBorrowRateFeed.getVariableBorrowRate() {
            assertTrue(false, "getVariableBorrowRate should revert if stale rate interval is reached");
        } catch {
            assertTrue(true);
        }
    }

    function test_VariablePoolBorrowRateFeed_getVariableBorrowRate_reverts_stale_rate() public {
        uint64 timestamp = uint64(block.timestamp);
        variablePoolBorrowRateFeed.setVariableBorrowRate(1.23e18);
        vm.warp(2 hours);
        vm.expectRevert(abi.encodeWithSelector(Errors.STALE_RATE.selector, timestamp));
        variablePoolBorrowRateFeed.getVariableBorrowRate();
    }

    function test_PriceFeed_getPrice_is_consistent() public {
        variablePoolBorrowRateFeed.setVariableBorrowRate(0.05e18);

        uint256 rate_1 = variablePoolBorrowRateFeed.getVariableBorrowRate();
        uint256 rate_2 = variablePoolBorrowRateFeed.getVariableBorrowRate();
        uint256 rate_3 = variablePoolBorrowRateFeed.getVariableBorrowRate();
        assertEq(rate_1, 0.05e18);
        assertEq(rate_1, rate_2, rate_3);
    }
}
