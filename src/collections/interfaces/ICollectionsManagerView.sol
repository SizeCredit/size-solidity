// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrder} from "@src/market/libraries/OfferLibrary.sol";

/// @title ICollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerView {
    function isValidCollectionId(uint256 collectionId) external view returns (bool);
    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool);
    /// @dev Should not revert
    function isCopyingCollectionRateProviderForMarket(
        address user,
        uint256 collectionId,
        address rateProvider,
        ISize market
    ) external view returns (bool);
    function getSubscribedCollections(address user) external view returns (uint256[] memory collectionIds);
    function getCollectionMarketCopyLimitOrders(uint256 collectionId, ISize market)
        external
        view
        returns (CopyLimitOrder memory loanOffer, CopyLimitOrder memory borrowOffer);
    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (bool success, uint256 apr);
    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (bool success, uint256 apr);
}
