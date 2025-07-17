// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ProposeSafeTxUpgradeToV1_8Script} from "@script/ProposeSafeTxUpgradeToV1_8.s.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

contract UpgradeToV1_8TestnetScript is ProposeSafeTxUpgradeToV1_8Script {
    function getCollectionMarkets(ISizeFactory _sizeFactory)
        public
        view
        override
        returns (ISize[] memory _collectionMarkets)
    {
        _collectionMarkets = new ISize[](1);
        ISize[] memory markets = getUnpausedMarkets(_sizeFactory);
        uint256 collectionMarketsLength = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            string memory symbol = markets[i].data().underlyingCollateralToken.symbol();
            if (Strings.equal(symbol, "WETH")) {
                _collectionMarkets[collectionMarketsLength++] = markets[i];
            }
        }

        require(collectionMarketsLength == 1, "Invalid number of collection markets");
    }

    function run() external override parseEnv broadcast {
        (address[] memory targets, bytes[] memory datas) =
            getTargetsAndDatas(sizeFactory, users, curator, rateProvider, collectionMarkets);

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success,) = targets[i].call(datas[i]);
            require(success, "Upgrade failed");
        }
    }
}
