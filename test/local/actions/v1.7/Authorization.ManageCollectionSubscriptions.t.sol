// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/market/SizeView.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract AuthorizationManageCollectionSubscriptionsTest is BaseTest {
    uint256 private collectionId;

    function setUp() public override {
        super.setUp();
        collectionId = _createCollection(james);
    }

    function test_AuthorizationManageCollectionSubscriptions_subscribeToCollectionsOnBehalfOf() public {
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(Action.MANAGE_COLLECTION_SUBSCRIPTIONS));

        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;

        vm.prank(candy);
        sizeFactory.subscribeToCollectionsOnBehalfOf(collectionIds, alice);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(alice, collectionId), true);

        vm.prank(candy);
        sizeFactory.unsubscribeFromCollectionsOnBehalfOf(collectionIds, alice);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(alice, collectionId), false);
    }

    function test_AuthorizationManageCollectionSubscriptions_validation() public {
        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.MANAGE_COLLECTION_SUBSCRIPTIONS
            )
        );
        vm.prank(alice);
        sizeFactory.subscribeToCollectionsOnBehalfOf(collectionIds, bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.MANAGE_COLLECTION_SUBSCRIPTIONS
            )
        );
        vm.prank(alice);
        sizeFactory.unsubscribeFromCollectionsOnBehalfOf(collectionIds, bob);
    }

    function test_AuthorizationManageCollectionSubscriptions_setUserCollectionCopyLimitOrderConfigsOnBehalfOf()
        public
    {
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(Action.MANAGE_COLLECTION_SUBSCRIPTIONS));

        CopyLimitOrderConfig memory copyLoanOfferConfig = CopyLimitOrderConfig({
            minTenor: 30 days,
            maxTenor: 90 days,
            minAPR: 0.05e18, // 5%
            maxAPR: 0.15e18, // 15%
            offsetAPR: 0.01e18 // 1% offset
        });

        CopyLimitOrderConfig memory copyBorrowOfferConfig = CopyLimitOrderConfig({
            minTenor: 60 days,
            maxTenor: 120 days,
            minAPR: 0.08e18, // 8%
            maxAPR: 0.2e18, // 20%
            offsetAPR: -0.02e18 // -2% offset
        });

        // Should not revert when authorized
        vm.prank(candy);
        sizeFactory.setUserCollectionCopyLimitOrderConfigsOnBehalfOf(
            collectionId, copyLoanOfferConfig, copyBorrowOfferConfig, alice
        );
    }

    function test_AuthorizationManageCollectionSubscriptions_setUserCollectionCopyLimitOrderConfigsOnBehalfOf_validation(
    ) public {
        CopyLimitOrderConfig memory copyLoanOfferConfig = CopyLimitOrderConfig({
            minTenor: 30 days,
            maxTenor: 90 days,
            minAPR: 0.05e18,
            maxAPR: 0.15e18,
            offsetAPR: 0.01e18
        });

        CopyLimitOrderConfig memory copyBorrowOfferConfig = CopyLimitOrderConfig({
            minTenor: 60 days,
            maxTenor: 120 days,
            minAPR: 0.08e18,
            maxAPR: 0.2e18,
            offsetAPR: -0.02e18
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.MANAGE_COLLECTION_SUBSCRIPTIONS
            )
        );
        vm.prank(alice);
        sizeFactory.setUserCollectionCopyLimitOrderConfigsOnBehalfOf(
            collectionId, copyLoanOfferConfig, copyBorrowOfferConfig, bob
        );
    }
}
