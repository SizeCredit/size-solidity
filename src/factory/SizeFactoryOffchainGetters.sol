// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {ISizeFactoryOffchainGetters} from "@src/factory/interfaces/ISizeFactoryOffchainGetters.sol";
import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

import {SizeFactoryStorage} from "@src/factory/SizeFactoryStorage.sol";
import {ActionsBitmap, Authorization} from "@src/factory/libraries/Authorization.sol";

import {VERSION} from "@src/market/interfaces/ISize.sol";

/// @title SizeFactoryOffchainGetters
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
abstract contract SizeFactoryOffchainGetters is ISizeFactoryOffchainGetters, SizeFactoryStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ISizeFactoryOffchainGetters
    function getMarket(uint256 index) external view returns (ISize) {
        return ISize(markets.at(index));
    }

    /// @inheritdoc ISizeFactoryOffchainGetters
    function getMarketsCount() external view returns (uint256) {
        return markets.length();
    }

    /// @inheritdoc ISizeFactoryOffchainGetters
    function getMarkets() external view returns (ISize[] memory _markets) {
        _markets = new ISize[](markets.length());
        for (uint256 i = 0; i < _markets.length; i++) {
            _markets[i] = ISize(markets.at(i));
        }
    }

    /// @inheritdoc ISizeFactoryOffchainGetters
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

    /// @inheritdoc ISizeFactoryOffchainGetters
    function isAuthorizedAll(address operator, address onBehalfOf, ActionsBitmap actionsBitmap)
        external
        view
        returns (bool)
    {
        if (operator == onBehalfOf) {
            return true;
        } else {
            uint256 nonce = authorizationNonces[onBehalfOf];
            ActionsBitmap authorizationsActionsBitmap = authorizations[nonce][operator][onBehalfOf];
            return Authorization.toUint256(authorizationsActionsBitmap) & Authorization.toUint256(actionsBitmap)
                == Authorization.toUint256(actionsBitmap);
        }
    }

    /// @inheritdoc ISizeFactoryOffchainGetters
    function version() external pure returns (string memory) {
        return VERSION;
    }
}
