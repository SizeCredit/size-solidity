// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

/// @title IAaveAdapter
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Interface for the Aave Adapter
interface IAaveAdapter is IAdapter {
    /// @notice Returns the liquidity index of the pool
    /// @return The liquidity index of the pool
    function liquidityIndex() external view returns (uint256);
}
