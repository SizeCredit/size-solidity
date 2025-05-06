// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CopyLimitOrder} from "@src/market/libraries/OfferLibrary.sol";

import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";

import {ICollectionsManagerCuratorActions} from "@src/collections/interfaces/ICollectionsManagerCuratorActions.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

/// @title CollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerCuratorActions}.
abstract contract CollectionsManagerCuratorActions is
    ICollectionsManagerCuratorActions,
    CollectionsManagerBase,
    ERC721EnumerableUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event AddMarketToCollection(
        uint256 indexed collectionId,
        address indexed market,
        CopyLimitOrder copyLoanOffer,
        CopyLimitOrder copyBorrowOffer
    );
    event RemoveMarketFromCollection(uint256 indexed collectionId, address indexed market);
    event AddRateProviderToMarket(uint256 indexed collectionId, address indexed market, address indexed rateProvider);
    event RemoveRateProviderFromMarket(
        uint256 indexed collectionId, address indexed market, address indexed rateProvider
    );

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error CollectionCuratorMismatch(uint256 collectionId, address expectedCurator, address curator);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyCollectionCurator(uint256 collectionId) {
        if (ownerOf(collectionId) != msg.sender) {
            revert CollectionCuratorMismatch(collectionId, ownerOf(collectionId), msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CURATOR ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollectionsManagerCuratorActions
    function createCollection() external returns (uint256 collectionId) {
        collectionId = collectionIdCounter++;
        _safeMint(msg.sender, collectionId);
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function addMarketsToCollection(
        uint256 collectionId,
        ISize[] memory markets,
        CopyLimitOrder[] memory copyLoanOffers,
        CopyLimitOrder[] memory copyBorrowOffers
    ) external onlyCollectionCurator(collectionId) {
        if (markets.length != copyLoanOffers.length || markets.length != copyBorrowOffers.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }

        for (uint256 i = 0; i < markets.length; i++) {
            if (!sizeFactory.isMarket(address(markets[i]))) {
                revert Errors.INVALID_MARKET(address(markets[i]));
            }
            if (copyLoanOffers[i].minTenor > copyLoanOffers[i].maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(copyLoanOffers[i].minTenor, copyLoanOffers[i].maxTenor);
            }
            if (copyLoanOffers[i].minAPR > copyLoanOffers[i].maxAPR) {
                revert Errors.INVALID_APR_RANGE(copyLoanOffers[i].minAPR, copyLoanOffers[i].maxAPR);
            }
            if (copyBorrowOffers[i].minTenor > copyBorrowOffers[i].maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(copyBorrowOffers[i].minTenor, copyBorrowOffers[i].maxTenor);
            }
            if (copyBorrowOffers[i].minAPR > copyBorrowOffers[i].maxAPR) {
                revert Errors.INVALID_APR_RANGE(copyBorrowOffers[i].minAPR, copyBorrowOffers[i].maxAPR);
            }

            collections[collectionId][markets[i]].exists = true;
            collections[collectionId][markets[i]].copyLoanOffer = copyLoanOffers[i];
            collections[collectionId][markets[i]].copyBorrowOffer = copyBorrowOffers[i];

            emit AddMarketToCollection(collectionId, address(markets[i]), copyLoanOffers[i], copyBorrowOffers[i]);
        }
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets)
        external
        onlyCollectionCurator(collectionId)
    {
        for (uint256 i = 0; i < markets.length; i++) {
            delete collections[collectionId][markets[i]];
            emit RemoveMarketFromCollection(collectionId, address(markets[i]));
        }
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function addRateProvidersToCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external
        onlyCollectionCurator(collectionId)
    {
        if (!collections[collectionId][market].exists) {
            revert MarketNotInCollection(collectionId, address(market));
        }

        for (uint256 i = 0; i < rateProviders.length; i++) {
            collections[collectionId][market].rateProviders.add(rateProviders[i]);
            emit AddRateProviderToMarket(collectionId, address(market), rateProviders[i]);
        }
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function removeRateProvidersFromCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external
        onlyCollectionCurator(collectionId)
    {
        if (!collections[collectionId][market].exists) {
            revert MarketNotInCollection(collectionId, address(market));
        }

        for (uint256 i = 0; i < rateProviders.length; i++) {
            collections[collectionId][market].rateProviders.remove(rateProviders[i]);
            emit RemoveRateProviderFromMarket(collectionId, address(market), rateProviders[i]);
        }
    }
}
