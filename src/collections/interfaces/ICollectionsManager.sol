// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ICollectionsManagerCuratorActions} from "@src/collections/interfaces/ICollectionsManagerCuratorActions.sol";
import {ICollectionsManagerUserActions} from "@src/collections/interfaces/ICollectionsManagerUserActions.sol";
import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";

/// @title ICollectionsManager
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManager is
    ICollectionsManagerCuratorActions,
    ICollectionsManagerUserActions,
    ICollectionsManagerView
{}
