// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ISizeFactoryV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory v1.8
interface ISizeFactoryV1_8 {
    /// @notice Call a market with data. This can be used to batch operations on multiple markets.
    /// @param market The market to call
    /// @param data The data to call the market with
    /// @dev Anybody can do arbitrary Size calls with this function, so users MUST revoke authorizations at the end of the transaction.
    ///      Since this function executes arbitrary calls on Size markets, it should not have any trust assumptions on the ACL of factory-executed calls.
    function callMarket(ISize market, bytes calldata data) external returns (bytes memory);
}
