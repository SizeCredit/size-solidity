// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ICollectionsManagerUserActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerUserActions {
    function subscribeUserToCollections(address user, uint256[] memory collectionIds) external;
    function unsubscribeUserFromCollections(address user, uint256[] memory collectionIds) external;
}
