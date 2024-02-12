// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract TimestampHelper {
    function getCurrentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }
}
