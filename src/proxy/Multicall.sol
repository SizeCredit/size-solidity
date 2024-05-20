// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Reference:  Contracts (last updated v5.0.0) (utils/Multicall.sol)

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IMulticall} from "@src/interfaces/IMulticall.sol";

/// @notice Provides a function to batch together multiple calls in a single external call.
/// @author OpenZeppelin (https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v5.0.2/contracts/utils/Multicall.sol), Size
/// @dev Add `payable` keyword to OpenZeppelin multicall implementation
///      Functions should not rely on `msg.value`. See the security implications of this change:
///        - https://github.com/sherlock-audit/2023-06-tokemak-judging/issues/215
///        - https://github.com/Uniswap/v3-periphery/issues/52
///        - https://forum.openzeppelin.com/t/query-regarding-multicall-fucntion-in-multicallupgradeable-sol/35537
///        - https://twitter.com/haydenzadams/status/1427784837738418180?lang=en
abstract contract Multicall is IMulticall {
    /// @dev Receives and executes a batch of function calls on this contract.
    /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
}
