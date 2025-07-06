// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";

import {ICollectionsManager} from "@src/collections/interfaces/ICollectionsManager.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";
import {BuyCreditLimitOnBehalfOfParams, BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {
    SellCreditLimitOnBehalfOfParams, SellCreditLimitParams
} from "@src/market/libraries/actions/SellCreditLimit.sol";

import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {MarketFactoryLibrary} from "@src/factory/libraries/MarketFactoryLibrary.sol";

import {NonTransferrableRebasingTokenVaultLibrary} from
    "@src/factory/libraries/NonTransferrableRebasingTokenVaultLibrary.sol";
import {PriceFeedFactoryLibrary} from "@src/factory/libraries/PriceFeedFactoryLibrary.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {SizeFactoryEvents} from "@src/factory/SizeFactoryEvents.sol";
import {SizeFactoryOffchainGetters} from "@src/factory/SizeFactoryOffchainGetters.sol";
import {Action, ActionsBitmap, Authorization} from "@src/factory/libraries/Authorization.sol";

import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";
import {ISizeFactoryV1_8} from "@src/factory/interfaces/ISizeFactoryV1_8.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {CollectionsManager} from "@src/collections/CollectionsManager.sol";

import {BORROW_RATE_UPDATER_ROLE, KEEPER_ROLE, PAUSER_ROLE} from "@src/factory/interfaces/ISizeFactory.sol";

/// @title SizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
/// @dev Expects `AccessControlUpgradeable` to have a single DEFAULT_ADMIN_ROLE role address set.
contract SizeFactory is
    ISizeFactory,
    SizeFactoryOffchainGetters,
    SizeFactoryEvents,
    ERC721Holder, // required for `reinitialize`
    MulticallUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __Multicall_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _owner);
        _grantRole(KEEPER_ROLE, _owner);
        _grantRole(BORROW_RATE_UPDATER_ROLE, _owner);
    }

    /// @inheritdoc ISizeFactoryV1_8
    // slither-disable-start calls-loop
    // slither-disable-start reentrancy-benign
    // slither-disable-start uninitialized-local
    function reinitialize(
        ICollectionsManager _collectionsManager,
        address[] memory _users,
        address _curator,
        address _rateProvider,
        ISize[] memory _collectionMarkets
    ) external onlyRole(DEFAULT_ADMIN_ROLE) reinitializer(1_08_00) {
        if (address(_collectionsManager) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        collectionsManager = _collectionsManager;
        emit CollectionsManagerSet(address(0), address(_collectionsManager));

        if (_curator == address(0) || _rateProvider == address(0)) {
            // no migration required
            return;
        }

        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionsManager.createCollection();

        CopyLimitOrderConfig[] memory noCopies = new CopyLimitOrderConfig[](_collectionMarkets.length);
        CopyLimitOrderConfig[] memory fullCopies = new CopyLimitOrderConfig[](_collectionMarkets.length);
        for (uint256 i = 0; i < _collectionMarkets.length; i++) {
            noCopies[i] =
                CopyLimitOrderConfig({minTenor: 0, maxTenor: 0, minAPR: 0, maxAPR: 0, offsetAPR: type(int256).min});

            fullCopies[i] = CopyLimitOrderConfig({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0,
                maxAPR: type(uint256).max,
                offsetAPR: 0
            });
        }
        collectionsManager.setCollectionMarketConfigs(collectionIds[0], _collectionMarkets, fullCopies, noCopies);
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = _rateProvider;
        for (uint256 i = 0; i < _collectionMarkets.length; i++) {
            collectionsManager.addRateProvidersToCollectionMarket(
                collectionIds[0], _collectionMarkets[i], rateProviders
            );
        }

        Action[] memory actions = new Action[](2);
        actions[0] = Action.BUY_CREDIT_LIMIT;
        actions[1] = Action.SELL_CREDIT_LIMIT;

        for (uint256 i = 0; i < _users.length; i++) {
            collectionsManager.subscribeUserToCollections(_users[i], collectionIds);
            _setAuthorization(address(this), _users[i], Authorization.getActionsBitmap(actions));
            for (uint256 j = 0; j < _collectionMarkets.length; j++) {
                BuyCreditLimitOnBehalfOfParams memory buyCreditLimitOnBehalfOfParams;
                buyCreditLimitOnBehalfOfParams.onBehalfOf = _users[i];

                _collectionMarkets[j].buyCreditLimitOnBehalfOf(buyCreditLimitOnBehalfOfParams);

                SellCreditLimitOnBehalfOfParams memory sellCreditLimitOnBehalfOfParams;
                sellCreditLimitOnBehalfOfParams.onBehalfOf = _users[i];

                _collectionMarkets[j].sellCreditLimitOnBehalfOf(sellCreditLimitOnBehalfOfParams);
            }
            _setAuthorization(address(this), _users[i], Authorization.nullActionsBitmap());
        }

        ERC721EnumerableUpgradeable(address(_collectionsManager)).safeTransferFrom(
            address(this), address(_curator), collectionIds[0]
        );
    }
    // slither-disable-end uninitialized-local
    // slither-disable-end reentrancy-benign
    // slither-disable-end calls-loop

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @inheritdoc ISizeFactory
    function setSizeImplementation(address _sizeImplementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_sizeImplementation == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit SizeImplementationSet(sizeImplementation, _sizeImplementation);
        sizeImplementation = _sizeImplementation;
    }

    /// @inheritdoc ISizeFactory
    function setNonTransferrableRebasingTokenVaultImplementation(address _nonTransferrableTokenVaultImplementation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_nonTransferrableTokenVaultImplementation == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit NonTransferrableRebasingTokenVaultImplementationSet(
            nonTransferrableTokenVaultImplementation, _nonTransferrableTokenVaultImplementation
        );
        nonTransferrableTokenVaultImplementation = _nonTransferrableTokenVaultImplementation;
    }

    function setCollectionsManager(ICollectionsManager _collectionsManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit CollectionsManagerSet(address(collectionsManager), address(_collectionsManager));
        collectionsManager = _collectionsManager;
    }

    /// @inheritdoc ISizeFactory
    function createMarket(
        InitializeFeeConfigParams calldata feeConfigParams,
        InitializeRiskConfigParams calldata riskConfigParams,
        InitializeOracleParams calldata oracleParams,
        InitializeDataParams calldata dataParams
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (ISize market) {
        address admin = msg.sender;
        market = MarketFactoryLibrary.createMarket(
            sizeImplementation, admin, feeConfigParams, riskConfigParams, oracleParams, dataParams
        );
        // slither-disable-next-line unused-return
        markets.add(address(market));
        emit CreateMarket(address(market));
    }

    /// @inheritdoc ISizeFactory
    function createBorrowTokenVault(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (NonTransferrableRebasingTokenVault borrowTokenVault)
    {
        address admin = msg.sender;
        borrowTokenVault = NonTransferrableRebasingTokenVaultLibrary.createNonTransferrableRebasingTokenVault(
            nonTransferrableTokenVaultImplementation, admin, variablePool, underlyingBorrowToken
        );
        emit CreateBorrowTokenVault(address(borrowTokenVault));
    }

    /// @inheritdoc ISizeFactory
    function createPriceFeed(PriceFeedParams memory _priceFeedParams)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (PriceFeed priceFeed)
    {
        priceFeed = PriceFeedFactoryLibrary.createPriceFeed(_priceFeedParams);
        emit CreatePriceFeed(address(priceFeed));
    }

    /// @inheritdoc ISizeFactory
    function isMarket(address candidate) public view returns (bool) {
        return markets.contains(candidate);
    }

    /// @inheritdoc ISizeFactoryV1_7
    function setAuthorization(address operator, ActionsBitmap actionsBitmap) external override(ISizeFactoryV1_7) {
        // validate msg.sender
        // N/A

        _setAuthorization(operator, msg.sender, actionsBitmap);
    }

    function _setAuthorization(address operator, address onBehalfOf, ActionsBitmap actionsBitmap) internal {
        // validate operator
        if (operator == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        // validate actionsBitmap
        if (!Authorization.isValid(actionsBitmap)) {
            revert Errors.INVALID_ACTIONS_BITMAP(Authorization.toUint256(actionsBitmap));
        }

        uint256 nonce = authorizationNonces[onBehalfOf];
        emit SetAuthorization(onBehalfOf, operator, Authorization.toUint256(actionsBitmap), nonce);
        authorizations[nonce][operator][onBehalfOf] = actionsBitmap;
    }

    /// @inheritdoc ISizeFactoryV1_7
    function revokeAllAuthorizations() external override(ISizeFactoryV1_7) {
        emit RevokeAllAuthorizations(msg.sender);
        authorizationNonces[msg.sender]++;
    }

    /// @inheritdoc ISizeFactoryV1_7
    function isAuthorized(address operator, address onBehalfOf, Action action) public view returns (bool) {
        if (operator == onBehalfOf) {
            return true;
        } else {
            uint256 nonce = authorizationNonces[onBehalfOf];
            return Authorization.isActionSet(authorizations[nonce][operator][onBehalfOf], action);
        }
    }

    /// @inheritdoc ISizeFactoryV1_8
    function callMarket(ISize market, bytes calldata data) external returns (bytes memory result) {
        if (!isMarket(address(market))) {
            revert Errors.INVALID_MARKET(address(market));
        }
        result = Address.functionCall(address(market), data);
    }

    /// @inheritdoc ISizeFactoryV1_8
    function subscribeToCollections(uint256[] memory collectionIds) external {
        return subscribeToCollectionsOnBehalfOf(collectionIds, msg.sender);
    }

    /// @inheritdoc ISizeFactoryV1_8
    function unsubscribeFromCollections(uint256[] memory collectionIds) external {
        return unsubscribeFromCollectionsOnBehalfOf(collectionIds, msg.sender);
    }

    /// @inheritdoc ISizeFactoryV1_8
    function subscribeToCollectionsOnBehalfOf(uint256[] memory collectionIds, address onBehalfOf) public {
        if (!isAuthorized(msg.sender, onBehalfOf, Action.MANAGE_COLLECTION_SUBSCRIPTIONS)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.MANAGE_COLLECTION_SUBSCRIPTIONS));
        }
        collectionsManager.subscribeUserToCollections(onBehalfOf, collectionIds);
    }

    /// @inheritdoc ISizeFactoryV1_8
    function unsubscribeFromCollectionsOnBehalfOf(uint256[] memory collectionIds, address onBehalfOf) public {
        if (!isAuthorized(msg.sender, onBehalfOf, Action.MANAGE_COLLECTION_SUBSCRIPTIONS)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.MANAGE_COLLECTION_SUBSCRIPTIONS));
        }
        collectionsManager.unsubscribeUserFromCollections(onBehalfOf, collectionIds);
    }

    /// @inheritdoc ISizeFactoryV1_8
    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256)
    {
        return collectionsManager.getLoanOfferAPR(user, collectionId, market, rateProvider, tenor);
    }

    /// @inheritdoc ISizeFactoryV1_8
    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256)
    {
        return collectionsManager.getBorrowOfferAPR(user, collectionId, market, rateProvider, tenor);
    }

    function isBorrowAPRLowerThanLoanOfferAPRs(address user, uint256 borrowAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool)
    {
        return collectionsManager.isBorrowAPRLowerThanLoanOfferAPRs(user, borrowAPR, market, tenor);
    }

    function isLoanAPRGreaterThanBorrowOfferAPRs(address user, uint256 loanAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool)
    {
        return collectionsManager.isLoanAPRGreaterThanBorrowOfferAPRs(user, loanAPR, market, tenor);
    }
}
