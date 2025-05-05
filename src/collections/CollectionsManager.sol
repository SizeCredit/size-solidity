// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {CollectionsManagerCuratorActions} from "@src/collections/actions/CollectionsManagerCuratorActions.sol";
import {CollectionsManagerUserActions} from "@src/collections/actions/CollectionsManagerUserActions.sol";
import {CollectionsManagerView} from "@src/collections/actions/CollectionsManagerView.sol";

import {ICollectionsManager} from "@src/collections/interfaces/ICollectionsManager.sol";

import {DEFAULT_ADMIN_ROLE, ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title CollectionsManager
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManager}.
contract CollectionsManager is
    ICollectionsManager,
    CollectionsManagerBase,
    ERC721EnumerableUpgradeable,
    CollectionsManagerCuratorActions,
    CollectionsManagerView,
    CollectionsManagerUserActions,
    MulticallUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(ISizeFactory _sizeFactory) external initializer {
        __ERC721Enumerable_init();
        __ERC721_init("Size Collections", "SIZE_COLLECTIONS");
        __Multicall_init();
        __UUPSUpgradeable_init();

        sizeFactory = _sizeFactory;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlySizeFactoryHasRole(DEFAULT_ADMIN_ROLE)
    {}

    function _baseURI() internal view virtual override returns (string memory) {
        return string.concat("https://api.size.credit/collections/", Strings.toString(block.chainid), "/");
    }
}
