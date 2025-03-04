// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {ISizeFactoryGetters} from "@src/factory/interfaces/ISizeFactoryGetters.sol";
import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

import {SizeFactoryStorage} from "@src/factory/SizeFactoryStorage.sol";

import {ActionsBitmap, Authorization} from "@src/factory/libraries/Authorization.sol";

import {VERSION} from "@src/market/interfaces/ISize.sol";

/// @title SizeFactoryGetters
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
abstract contract SizeFactoryGetters is ISizeFactoryGetters, SizeFactoryStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ISizeFactoryGetters
    function isPriceFeed(address candidate) external view returns (bool) {
        return priceFeeds.contains(candidate);
    }

    /// @inheritdoc ISizeFactoryGetters
    function isBorrowATokenV1_5(address candidate) external view returns (bool) {
        return borrowATokensV1_5.contains(candidate);
    }

    /// @inheritdoc ISizeFactoryGetters
    function getMarket(uint256 index) external view returns (ISize) {
        return ISize(markets.at(index));
    }

    /// @inheritdoc ISizeFactoryGetters
    function getPriceFeed(uint256 index) external view returns (PriceFeed) {
        return PriceFeed(priceFeeds.at(index));
    }

    /// @inheritdoc ISizeFactoryGetters
    function getBorrowATokenV1_5(uint256 index) external view returns (IERC20Metadata) {
        return IERC20Metadata(borrowATokensV1_5.at(index));
    }

    /// @inheritdoc ISizeFactoryGetters
    function getMarketsCount() external view returns (uint256) {
        return markets.length();
    }

    /// @inheritdoc ISizeFactoryGetters
    function getPriceFeedsCount() external view returns (uint256) {
        return priceFeeds.length();
    }

    /// @inheritdoc ISizeFactoryGetters
    function getBorrowATokensV1_5Count() external view returns (uint256) {
        return borrowATokensV1_5.length();
    }

    /// @inheritdoc ISizeFactoryGetters
    function getMarkets() external view returns (ISize[] memory _markets) {
        _markets = new ISize[](markets.length());
        for (uint256 i = 0; i < _markets.length; i++) {
            _markets[i] = ISize(markets.at(i));
        }
    }

    /// @inheritdoc ISizeFactoryGetters
    function getPriceFeeds() external view returns (PriceFeed[] memory _priceFeeds) {
        _priceFeeds = new PriceFeed[](priceFeeds.length());
        for (uint256 i = 0; i < _priceFeeds.length; i++) {
            _priceFeeds[i] = PriceFeed(priceFeeds.at(i));
        }
    }

    /// @inheritdoc ISizeFactoryGetters
    function getBorrowATokensV1_5() external view returns (IERC20Metadata[] memory _borrowATokensV1_5) {
        _borrowATokensV1_5 = new IERC20Metadata[](borrowATokensV1_5.length());
        for (uint256 i = 0; i < _borrowATokensV1_5.length; i++) {
            _borrowATokensV1_5[i] = IERC20Metadata(borrowATokensV1_5.at(i));
        }
    }

    /// @inheritdoc ISizeFactoryGetters
    function getMarketDescriptions() external view returns (string[] memory descriptions) {
        descriptions = new string[](markets.length());
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < descriptions.length; i++) {
            ISize size = ISize(markets.at(i));
            uint256 crLiquidationPercent = Math.mulDivDown(100, size.riskConfig().crLiquidation, PERCENT);
            descriptions[i] = string.concat(
                "Size | ",
                size.data().underlyingCollateralToken.symbol(),
                " | ",
                size.data().underlyingBorrowToken.symbol(),
                " | ",
                Strings.toString(crLiquidationPercent),
                " | ",
                size.version()
            );
        }
        // slither-disable-end calls-loop
    }

    /// @inheritdoc ISizeFactoryGetters
    function getPriceFeedDescriptions() external view returns (string[] memory descriptions) {
        descriptions = new string[](priceFeeds.length());
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < descriptions.length; i++) {
            PriceFeed priceFeed = PriceFeed(priceFeeds.at(i));
            (bool success, bytes memory data) =
                address(priceFeed).staticcall(abi.encodeWithSelector(IPriceFeedV1_5_2.description.selector));
            if (success) {
                // IPriceFeedV1_5_2
                descriptions[i] = abi.decode(data, (string));
            } else {
                // IPriceFeedV1_5
                descriptions[i] = string.concat(
                    "PriceFeed | ", priceFeed.base().description(), " | ", priceFeed.quote().description()
                );
            }
        }
        // slither-disable-end calls-loop
    }

    /// @inheritdoc ISizeFactoryGetters
    function getBorrowATokenV1_5Descriptions() external view returns (string[] memory descriptions) {
        descriptions = new string[](borrowATokensV1_5.length());
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < descriptions.length; i++) {
            IERC20Metadata borrowATokenV1_5 = IERC20Metadata(borrowATokensV1_5.at(i));
            descriptions[i] = borrowATokenV1_5.symbol();
        }
        // slither-disable-end calls-loop
    }

    /// @inheritdoc ISizeFactoryGetters
    function isAuthorizedAll(address operator, address onBehalfOf, ActionsBitmap actionsBitmap)
        external
        view
        returns (bool)
    {
        if (operator == onBehalfOf) {
            return true;
        } else {
            uint256 nonce = authorizationNonces[onBehalfOf];
            ActionsBitmap authorizations = authorizations[nonce][operator][onBehalfOf];
            return Authorization.toUint256(authorizations) & Authorization.toUint256(actionsBitmap)
                == Authorization.toUint256(actionsBitmap);
        }
    }

    /// @inheritdoc ISizeFactoryGetters
    function version() external pure returns (string memory) {
        return VERSION;
    }
}
