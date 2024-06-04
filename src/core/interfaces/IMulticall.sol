// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title Multicall
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface IMulticall {
    /// @notice Executes multiple calls in a single transaction
    /// @dev This function allows for batch processing of multiple interactions with the protocol in a single transaction.
    ///      This allows users to take actions that would otherwise be denied due to deposit limits.
    /// @param data An array of bytes encoded function calls to be executed in sequence.
    /// @return results An array of bytes representing the return data from each function call executed.
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
