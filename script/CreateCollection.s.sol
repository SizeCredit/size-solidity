// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2 as console} from "forge-std/Script.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {NetworkConfiguration, Networks, Contract} from "@script/Networks.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ICollectionsManager} from "@src/collections/interfaces/ICollectionsManager.sol";

contract CreateCollectionScript is BaseScript, Networks {
    address curator;
    address rateProvider;

    function setUp() public {
        curator = vm.envAddress("CURATOR");
        rateProvider = vm.envAddress("RATE_PROVIDER");
    }

    function run() public  broadcast {
        SizeFactory sizeFactory = SizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);
        ICollectionsManager collectionsManager = sizeFactory.collectionsManager();
        uint256 collectionId = collectionsManager.createCollection();
        ISize[] memory markets = sizeFactory.getMarkets();
        ISize[] memory unpausedMarkets = new ISize[](markets.length);
        uint256 j = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            if (!PausableUpgradeable(address(markets[i])).paused()) {
                unpausedMarkets[j] = markets[i];
                j++;
            }
        }
        _unsafeSetLength(unpausedMarkets, j);
        collectionsManager.addMarketsToCollection(collectionId, unpausedMarkets);
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        for (uint256 i = 0; i < unpausedMarkets.length; i++) {
            collectionsManager.addRateProvidersToCollectionMarket(collectionId, unpausedMarkets[i], rateProviders);
        }
        IERC721(address(collectionsManager)).safeTransferFrom(msg.sender, curator, collectionId);
    }
}
