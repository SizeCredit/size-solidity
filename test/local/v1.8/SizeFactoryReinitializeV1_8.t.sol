// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {ICollectionsManager} from "@src/collections/interfaces/ICollectionsManager.sol";
import {Action} from "@src/factory/libraries/Authorization.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract SizeFactoryReinitializeV1_8Test is BaseTest {
    bytes32 internal COLLECTIONS_MANAGER_SLOT = bytes32(uint256(7));

    function setUp() public override {
        super.setUp();
        _deploySizeMarket2();
        vm.store(address(sizeFactory), COLLECTIONS_MANAGER_SLOT, bytes32(uint256(uint160(address(0)))));
    }

    function test_SizeFactoryReinitializeV1_8_input_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        sizeFactory.reinitialize(ICollectionsManager(address(0)), new address[](0), address(0), new ISize[](0));

        address[] memory users = new address[](1);
        users[0] = alice;

        ISize[] memory invalidCollectionMarkets = new ISize[](1);
        invalidCollectionMarkets[0] = ISize(address(this));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MARKET.selector, address(this)));
        sizeFactory.reinitialize(collectionsManager, users, bob, invalidCollectionMarkets);
    }

    function test_SizeFactoryReinitializeV1_8_simple() public {
        sizeFactory.reinitialize(collectionsManager, new address[](0), address(0), new ISize[](0));

        assertEq(address(sizeFactory.collectionsManager()), address(collectionsManager));
    }

    function test_SizeFactoryReinitializeV1_8_full() public {
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = candy;
        address rateProvider = james;
        ISize[] memory collectionMarkets = new ISize[](1);
        collectionMarkets[0] = size1;

        sizeFactory.reinitialize(collectionsManager, users, rateProvider, collectionMarkets);

        uint256 collectionId = 0;

        assertEq(address(sizeFactory.collectionsManager()), address(collectionsManager));
        assertEq(ERC721EnumerableUpgradeable(address(collectionsManager)).ownerOf(collectionId), james);

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(collectionsManager.getSubscribedCollections(users[i]).length, 1);
            assertEq(size.getLoanOfferAPR(users[i], collectionId, rateProvider, 365 days), 0.03e18);

            assertEq(sizeFactory.isAuthorized(address(sizeFactory), users[i], Action.BUY_CREDIT_LIMIT), false);
            assertEq(sizeFactory.isAuthorized(address(sizeFactory), users[i], Action.SELL_CREDIT_LIMIT), false);
        }
    }
}
