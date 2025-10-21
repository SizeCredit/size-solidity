// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrderConfig, LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

/// @title CollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerView}.
abstract contract CollectionsManagerView is ICollectionsManagerView, CollectionsManagerBase {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using OfferLibrary for CopyLimitOrderConfig;
    using OfferLibrary for LimitOrder;

    /*//////////////////////////////////////////////////////////////
                            COLLECTION VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollectionsManagerView
    function isValidCollectionId(uint256 collectionId) public view returns (bool) {
        return collectionId < collectionIdCounter;
    }

    /// @inheritdoc ICollectionsManagerView
    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool) {
        return userToCollectionIds[user].contains(collectionId);
    }

    /// @inheritdoc ICollectionsManagerView
    function collectionContainsMarket(uint256 collectionId, ISize market) external view returns (bool) {
        if (!isValidCollectionId(collectionId)) {
            return false;
        }
        return collections[collectionId][market].initialized;
    }

    /// @inheritdoc ICollectionsManagerView
    function getCollectionMarketRateProviders(uint256 collectionId, ISize market)
        external
        view
        returns (address[] memory)
    {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        if (!collections[collectionId][market].initialized) {
            revert MarketNotInCollection(collectionId, address(market));
        }
        return collections[collectionId][market].rateProviders.values();
    }

    /// @inheritdoc ICollectionsManagerView
    function isCopyingCollectionMarketRateProvider(
        address user,
        uint256 collectionId,
        ISize market,
        address rateProvider
    ) public view returns (bool) {
        if (!isValidCollectionId(collectionId)) {
            return false;
        }
        if (!userToCollectionIds[user].contains(collectionId)) {
            return false;
        }
        if (!collections[collectionId][market].initialized) {
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

    function _isUserDefinedLimitOrderNull(address user, ISize market, bool isLoanOffer) private view returns (bool) {
        return isLoanOffer ? market.isUserDefinedLoanOfferNull(user) : market.isUserDefinedBorrowOfferNull(user);
    }

    /// @inheritdoc ICollectionsManagerView
    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr)
    {
        return getLimitOrderAPR(user, collectionId, market, rateProvider, tenor, true);
    }

    /// @inheritdoc ICollectionsManagerView
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
    ) public view returns (uint256 apr) {
        // if collectionId is RESERVED_ID, return the user-defined yield curve
        //   and ignore the user-defined CopyLimitOrderConfig params
        if (collectionId == RESERVED_ID) {
            return _getUserDefinedLimitOrderAPR(user, market, tenor, isLoanOffer);
        }
        // else if the user is not copying the collection market rate provider, revert
        else if (!isCopyingCollectionMarketRateProvider(user, collectionId, market, rateProvider)) {
            revert InvalidCollectionMarketRateProvider(collectionId, address(market), rateProvider);
        }
        // else, return the yield curve for that collection, market and rate provider
        else {
            // validate min/max tenor
            CopyLimitOrderConfig memory copyLimitOrder =
                _getCopyLimitOrderConfig(user, collectionId, market, isLoanOffer);
            if (tenor < copyLimitOrder.minTenor || tenor > copyLimitOrder.maxTenor) {
                revert InvalidTenor(tenor, copyLimitOrder.minTenor, copyLimitOrder.maxTenor);
            } else {
                uint256 baseAPR = _getUserDefinedLimitOrderAPR(rateProvider, market, tenor, isLoanOffer);
                // apply offset APR
                apr = SafeCast.toUint256(SafeCast.toInt256(baseAPR) + copyLimitOrder.offsetAPR);
                // validate min/max APR
                if (apr < copyLimitOrder.minAPR) {
                    apr = copyLimitOrder.minAPR;
                } else if (apr > copyLimitOrder.maxAPR) {
                    apr = copyLimitOrder.maxAPR;
                }
            }
        }
    }

    function _getUserDefinedLimitOrderAPR(address user, ISize market, uint256 tenor, bool isLoanOffer)
        private
        view
        returns (uint256 apr)
    {
        if (isLoanOffer) {
            return market.getUserDefinedLoanOfferAPR(user, tenor);
        } else {
            return market.getUserDefinedBorrowOfferAPR(user, tenor);
        }
    }

    /// @inheritdoc ICollectionsManagerView
    function isLoanAPRGreaterThanBorrowOfferAPRs(address user, uint256 loanAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool)
    {
        return _isAPRLowerThanOfferAPRs(user, loanAPR, market, tenor, true);
    }

    /// @inheritdoc ICollectionsManagerView
    function isBorrowAPRLowerThanLoanOfferAPRs(address user, uint256 borrowAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool)
    {
        return _isAPRLowerThanOfferAPRs(user, borrowAPR, market, tenor, false);
    }

    // slither-disable-start var-read-using-this
    // slither-disable-start calls-loop
    function _isAPRLowerThanOfferAPRs(address user, uint256 apr, ISize market, uint256 tenor, bool aprIsLoanAPR)
        private
        view
        returns (bool)
    {
        // collections check
        EnumerableSet.UintSet storage collectionIds = userToCollectionIds[user];
        for (uint256 i = 0; i < collectionIds.length(); i++) {
            uint256 collectionId = collectionIds.at(i);
            if (!collections[collectionId][market].initialized) {
                continue;
            }
            EnumerableSet.AddressSet storage rateProviders = collections[collectionId][market].rateProviders;
            for (uint256 j = 0; j < rateProviders.length(); j++) {
                address rateProvider = rateProviders.at(j);
                if (_isUserDefinedLimitOrderNull(rateProvider, market, !aprIsLoanAPR)) {
                    continue;
                }
                try this.getLimitOrderAPR(user, collectionId, market, rateProvider, tenor, !aprIsLoanAPR) returns (
                    uint256 otherAPR
                ) {
                    if ((aprIsLoanAPR && otherAPR >= apr) || (!aprIsLoanAPR && apr >= otherAPR)) {
                        return false;
                    }
                } catch (bytes memory) {
                    // N/A
                }
            }
        }

        // user-defined check
        if (_isUserDefinedLimitOrderNull(user, market, !aprIsLoanAPR)) {
            return true;
        } else {
            try this.getLimitOrderAPR(user, RESERVED_ID, market, address(0), tenor, !aprIsLoanAPR) returns (
                uint256 otherAPR
            ) {
                if ((aprIsLoanAPR && otherAPR >= apr) || (!aprIsLoanAPR && apr >= otherAPR)) {
                    return false;
                }
            } catch (bytes memory) {
                // N/A
            }

            return true;
        }
    }
    // slither-disable-end calls-loop
    // slither-disable-end var-read-using-this

    /*//////////////////////////////////////////////////////////////
                            COPY LIMIT ORDER VIEW
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the collection id is invalid or the market is not in the collection
    /// @dev Changed in v1.8.1
    function _getCopyLimitOrderConfig(address user, uint256 collectionId, ISize market, bool isLoanOffer)
        private
        view
        returns (CopyLimitOrderConfig memory copyLimitOrder)
    {
        copyLimitOrder = _getUserDefinedMarketCopyLimitOrderConfig(user, market, isLoanOffer);
        if (copyLimitOrder.isNull()) {
            copyLimitOrder = _getUserDefinedCollectionCopyLimitOrderConfig(user, collectionId, isLoanOffer);
        }
    }

    function _getUserDefinedMarketCopyLimitOrderConfig(address user, ISize market, bool isLoanOffer)
        private
        view
        returns (CopyLimitOrderConfig memory copyLimitOrder)
    {
        return isLoanOffer
            ? market.getUserDefinedCopyLoanOfferConfig(user)
            : market.getUserDefinedCopyBorrowOfferConfig(user);
    }

    function _getUserDefinedCollectionCopyLimitOrderConfig(address user, uint256 collectionId, bool isLoanOffer)
        private
        view
        returns (CopyLimitOrderConfig memory copyLimitOrder)
    {
        return isLoanOffer
            ? userToCollectionCopyLimitOrderConfigs[user][collectionId].copyLoanOfferConfig
            : userToCollectionCopyLimitOrderConfigs[user][collectionId].copyBorrowOfferConfig;
    }

    function _getCollectionMarketCopyLimitOrderConfig(address user, uint256 collectionId, bool isLoanOffer)
        private
        view
        returns (CopyLimitOrderConfig memory copyLimitOrder)
    {
        return isLoanOffer
            ? userToCollectionCopyLimitOrderConfigs[user][collectionId].copyLoanOfferConfig
            : userToCollectionCopyLimitOrderConfigs[user][collectionId].copyBorrowOfferConfig;
    }
}
