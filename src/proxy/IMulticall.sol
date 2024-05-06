// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

interface IMulticall {
    /// @notice Receives and executes a batch of function calls on this contract.
    /// @dev Reverts if any of the calls fails.
    /// @param data The encoded data for all the function calls to execute.
    /// @return results The results of all the function calls.
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
