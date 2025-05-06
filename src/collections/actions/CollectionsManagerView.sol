// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

/// @title CollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerView}.
abstract contract CollectionsManagerView is ICollectionsManagerView, CollectionsManagerBase {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using OfferLibrary for CopyLimitOrder;

    error InvalidCollectionMarketRateProvider(uint256 collectionId, address market, address rateProvider);
    error InvalidTenor(uint256 tenor, uint256 minTenor, uint256 maxTenor);

    /// @inheritdoc ICollectionsManagerView
    function isValidCollectionId(uint256 collectionId) public view returns (bool) {
        return collectionId < collectionIdCounter;
    }

    /// @inheritdoc ICollectionsManagerView
    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool) {
        return userToCollectionIds[user].contains(collectionId);
    }

    /// @inheritdoc ICollectionsManagerView
    function isCopyingCollectionRateProviderForMarket(
        address user,
        uint256 collectionId,
        address rateProvider,
        ISize market
    ) public view returns (bool) {
        if (!isValidCollectionId(collectionId)) {
            return false;
        }
        if (!userToCollectionIds[user].contains(collectionId)) {
            return false;
        }
        if (!collections[collectionId][market].exists) {
            return false;
        }
        return collections[collectionId][market].rateProviders.contains(rateProvider);
    }

    /// @inheritdoc ICollectionsManagerView
    function getSubscribedCollections(address user) external view returns (uint256[] memory collectionIds) {
        return userToCollectionIds[user].values();
    }

    /*//////////////////////////////////////////////////////////////
                            APR VIEW
    //////////////////////////////////////////////////////////////*/

    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr)
    {
        return getLimitOrderAPR(user, collectionId, market, rateProvider, tenor, true);
    }

    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr)
    {
        return getLimitOrderAPR(user, collectionId, market, rateProvider, tenor, false);
    }

    function getLimitOrderAPR(
        address user,
        uint256 collectionId,
        ISize market,
        address rateProvider,
        uint256 tenor,
        bool isLoanOffer
    ) private view returns (uint256 apr) {
        // if collectionId is RESERVED_ID and rateProvider is address(0), return the user-defined yield curve
        if (collectionId == RESERVED_ID && rateProvider == address(0)) {
            return getUserDefinedLimitOrderAPR(user, collectionId, market, rateProvider, tenor, isLoanOffer);
        }
        // else, return the yield curve for that collection, market and rate provider
        // if the user is not copying the collection rate provider for that market, revert
        else if (!isCopyingCollectionRateProviderForMarket(user, collectionId, rateProvider, market)) {
            revert InvalidCollectionMarketRateProvider(collectionId, address(market), rateProvider);
        }
        // else, return the rate-provider yield curve for that market and rate provider
        else {
            // validate min/max tenor
            CopyLimitOrder memory copyLimitOrder = getCopyLimitOrder(user, collectionId, market, isLoanOffer);
            if (tenor < copyLimitOrder.minTenor || tenor > copyLimitOrder.maxTenor) {
                revert InvalidTenor(tenor, copyLimitOrder.minTenor, copyLimitOrder.maxTenor);
            } else {
                // validate min/max APR
                apr = market.getUserDefinedLoanOfferAPR(rateProvider, tenor);
                if (apr < copyLimitOrder.minAPR) {
                    apr = copyLimitOrder.minAPR;
                } else if (apr > copyLimitOrder.maxAPR) {
                    apr = copyLimitOrder.maxAPR;
                }
            }
        }
    }

    function getUserDefinedLimitOrderAPR(
        address user,
        uint256 collectionId,
        ISize market,
        address rateProvider,
        uint256 tenor,
        bool isLoanOffer
    ) private view returns (uint256 apr) {
        if (isLoanOffer) {
            return market.getUserDefinedLoanOfferAPR(user, tenor);
        } else {
            return market.getUserDefinedBorrowOfferAPR(user, tenor);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            COLLECTION VIEW
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the collection id is invalid or the market is not in the collection
    function getCopyLimitOrder(address user, uint256 collectionId, ISize market, bool isLoanOffer)
        private
        view
        returns (CopyLimitOrder memory copyLimitOrder)
    {
        (CopyLimitOrder memory copyLoanOffer, CopyLimitOrder memory copyBorrowOffer) =
            getCollectionMarketCopyLimitOrders(collectionId, market);
        copyLimitOrder = isLoanOffer ? market.getCopyLoanOffer(user) : market.getCopyBorrowOffer(user);
        if (copyLimitOrder.isNull()) {
            copyLimitOrder = isLoanOffer ? copyLoanOffer : copyBorrowOffer;
        }
    }

    function getCollectionMarketCopyLimitOrders(uint256 collectionId, ISize market)
        public
        view
        returns (CopyLimitOrder memory copyLoanOffer, CopyLimitOrder memory copyBorrowOffer)
    {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        if (!collections[collectionId][market].exists) {
            revert MarketNotInCollection(collectionId, address(market));
        }
        return (collections[collectionId][market].copyLoanOffer, collections[collectionId][market].copyBorrowOffer);
    }

    function getCollectionMarketRateProviders(uint256 collectionId, ISize market)
        external
        view
        returns (address[] memory)
    {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        if (!collections[collectionId][market].exists) {
            revert MarketNotInCollection(collectionId, address(market));
        }
        return collections[collectionId][market].rateProviders.values();
    }
}
