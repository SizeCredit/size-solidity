// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

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
    function getCollectionBounds(uint256 collectionId)
        external
        view
        returns (uint256 minAPR, uint256 maxAPR, uint256 minTenor, uint256 maxTenor);
    function getLoanOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256); // user-defined lend curve
    function getBorrowOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256); // user-defined borrow curve
    function getLoanOfferAPR(address user, uint256 collectionId, address rateProvider, ISize market, uint256 tenor)
        external
        view
        returns (uint256); // RP lend curve
    function getBorrowOfferAPR(address user, uint256 collectionId, address rateProvider, ISize market, uint256 tenor)
        external
        view
        returns (uint256); // RP borrow curve
}
