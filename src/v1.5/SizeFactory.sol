// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";
import {MarketFactoryLibrary} from "@src/v1.5/libraries/MarketFactoryLibrary.sol";
import {NonTransferrableScaledTokenV1_5FactoryLibrary} from
    "@src/v1.5/libraries/NonTransferrableScaledTokenV1_5FactoryLibrary.sol";
import {PriceFeedFactoryLibrary} from "@src/v1.5/libraries/PriceFeedFactoryLibrary.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/PriceFeed.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";

import {VERSION} from "@src/interfaces/ISize.sol";

/// @title SizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
contract SizeFactory is ISizeFactory, Ownable2StepUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private markets;
    EnumerableSet.AddressSet private priceFeeds;
    EnumerableSet.AddressSet private borrowATokensV1_5;

    event MarketAdded(address indexed market, bool indexed existed);
    event MarketRemoved(address indexed market, bool indexed existed);
    event PriceFeedAdded(address indexed priceFeed, bool indexed existed);
    event PriceFeedRemoved(address indexed priceFeed, bool indexed existed);
    event BorrowATokenV1_5Added(address indexed borrowATokenV1_5, bool indexed existed);
    event BorrowATokenV1_5Removed(address indexed borrowATokenV1_5, bool indexed existed);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function createMarket(
        InitializeFeeConfigParams calldata feeConfigParams,
        InitializeRiskConfigParams calldata riskConfigParams,
        InitializeOracleParams calldata oracleParams,
        InitializeDataParams calldata dataParams
    ) external onlyOwner returns (ISize market) {
        market = MarketFactoryLibrary.createMarket(owner(), feeConfigParams, riskConfigParams, oracleParams, dataParams);
        _addMarket(market);
    }

    /// @inheritdoc ISizeFactory
    function addMarket(ISize market) external onlyOwner returns (bool existed) {
        existed = _addMarket(market);
    }

    function _addMarket(ISize market) internal returns (bool existed) {
        if (address(market) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = !markets.add(address(market));
        emit MarketAdded(address(market), existed);
    }

    /// @inheritdoc ISizeFactory
    function removeMarket(ISize market) external onlyOwner returns (bool existed) {
        if (address(market) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = markets.remove(address(market));
        emit MarketRemoved(address(market), existed);
    }

    function createPriceFeed(PriceFeedParams memory _priceFeedParams)
        external
        onlyOwner
        returns (PriceFeed priceFeed)
    {
        priceFeed = PriceFeedFactoryLibrary.createPriceFeed(_priceFeedParams);
        _addPriceFeed(priceFeed);
    }

    /// @inheritdoc ISizeFactory
    function addPriceFeed(PriceFeed priceFeed) external onlyOwner returns (bool existed) {
        existed = _addPriceFeed(priceFeed);
    }

    function _addPriceFeed(PriceFeed priceFeed) internal returns (bool existed) {
        if (address(priceFeed) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = !priceFeeds.add(address(priceFeed));
        emit PriceFeedAdded(address(priceFeed), existed);
    }

    /// @inheritdoc ISizeFactory
    function removePriceFeed(PriceFeed priceFeed) external onlyOwner returns (bool existed) {
        if (address(priceFeed) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = priceFeeds.remove(address(priceFeed));
        emit PriceFeedRemoved(address(priceFeed), existed);
    }

    function createBorrowATokenV1_5(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        onlyOwner
        returns (NonTransferrableScaledTokenV1_5 borrowATokenV1_5)
    {
        borrowATokenV1_5 = NonTransferrableScaledTokenV1_5FactoryLibrary.createNonTransferrableScaledTokenV1_5(
            owner(), variablePool, underlyingBorrowToken
        );
        _addBorrowATokenV1_5(borrowATokenV1_5);
    }

    /// @inheritdoc ISizeFactory
    function addBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) external onlyOwner returns (bool existed) {
        existed = _addBorrowATokenV1_5(borrowATokenV1_5);
    }

    function _addBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) internal returns (bool existed) {
        if (address(borrowATokenV1_5) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = !borrowATokensV1_5.add(address(borrowATokenV1_5));
        emit BorrowATokenV1_5Added(address(borrowATokenV1_5), existed);
    }

    /// @inheritdoc ISizeFactory
    function removeBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) external onlyOwner returns (bool existed) {
        if (address(borrowATokenV1_5) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = borrowATokensV1_5.remove(address(borrowATokenV1_5));
        emit BorrowATokenV1_5Removed(address(borrowATokenV1_5), existed);
    }

    /// @inheritdoc ISizeFactory
    function isMarket(address candidate) external view returns (bool) {
        return markets.contains(candidate);
    }

    /// @inheritdoc ISizeFactory
    function isPriceFeed(address candidate) external view returns (bool) {
        return priceFeeds.contains(candidate);
    }

    /// @inheritdoc ISizeFactory
    function isBorrowATokenV1_5(address candidate) external view returns (bool) {
        return borrowATokensV1_5.contains(candidate);
    }

    /// @inheritdoc ISizeFactory
    function getMarket(uint256 index) external view returns (ISize) {
        return ISize(markets.at(index));
    }

    /// @inheritdoc ISizeFactory
    function getPriceFeed(uint256 index) external view returns (PriceFeed) {
        return PriceFeed(priceFeeds.at(index));
    }

    /// @inheritdoc ISizeFactory
    function getBorrowATokenV1_5(uint256 index) external view returns (IERC20Metadata) {
        return IERC20Metadata(borrowATokensV1_5.at(index));
    }

    /// @inheritdoc ISizeFactory
    function getMarkets() external view returns (ISize[] memory _markets) {
        _markets = new ISize[](markets.length());
        for (uint256 i = 0; i < _markets.length; i++) {
            _markets[i] = ISize(markets.at(i));
        }
    }

    /// @inheritdoc ISizeFactory
    function getPriceFeeds() external view returns (PriceFeed[] memory _priceFeeds) {
        _priceFeeds = new PriceFeed[](priceFeeds.length());
        for (uint256 i = 0; i < _priceFeeds.length; i++) {
            _priceFeeds[i] = PriceFeed(priceFeeds.at(i));
        }
    }

    /// @inheritdoc ISizeFactory
    function getBorrowATokensV1_5() external view returns (IERC20Metadata[] memory _borrowATokensV1_5) {
        _borrowATokensV1_5 = new IERC20Metadata[](borrowATokensV1_5.length());
        for (uint256 i = 0; i < _borrowATokensV1_5.length; i++) {
            _borrowATokensV1_5[i] = IERC20Metadata(borrowATokensV1_5.at(i));
        }
    }

    /// @inheritdoc ISizeFactory
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

    /// @inheritdoc ISizeFactory
    function getPriceFeedDescriptions() external view returns (string[] memory descriptions) {
        descriptions = new string[](priceFeeds.length());
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < descriptions.length; i++) {
            PriceFeed priceFeed = PriceFeed(priceFeeds.at(i));
            descriptions[i] = string.concat(
                "PriceFeed | ",
                priceFeed.chainlinkPriceFeed().quoteAggregator().description(),
                " | ",
                priceFeed.chainlinkPriceFeed().quoteAggregator().description(),
                " | ",
                Strings.toString(priceFeed.uniswapV3PriceFeed().twapWindow()),
                " | ",
                Strings.toString(priceFeed.uniswapV3PriceFeed().feeTier())
            );
        }
        // slither-disable-end calls-loop
    }

    /// @inheritdoc ISizeFactory
    function getBorrowATokenV1_5Descriptions() external view returns (string[] memory descriptions) {
        descriptions = new string[](borrowATokensV1_5.length());
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < descriptions.length; i++) {
            IERC20Metadata borrowATokenV1_5 = IERC20Metadata(borrowATokensV1_5.at(i));
            descriptions[i] = borrowATokenV1_5.symbol();
        }
        // slither-disable-end calls-loop
    }

    /// @inheritdoc ISizeFactory
    function getMarketsCount() external view returns (uint256) {
        return markets.length();
    }

    /// @inheritdoc ISizeFactory
    function getPriceFeedsCount() external view returns (uint256) {
        return priceFeeds.length();
    }

    /// @inheritdoc ISizeFactory
    function getBorrowATokensV1_5Count() external view returns (uint256) {
        return borrowATokensV1_5.length();
    }

    /// @inheritdoc ISizeFactory
    function version() external pure returns (string memory) {
        return VERSION;
    }
}
