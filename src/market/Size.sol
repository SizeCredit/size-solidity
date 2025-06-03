// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/market/libraries/actions/UpdateConfig.sol";

import {
    SellCreditLimit,
    SellCreditLimitOnBehalfOfParams,
    SellCreditLimitParams
} from "@src/market/libraries/actions/SellCreditLimit.sol";
import {
    SellCreditMarket,
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {
    BuyCreditMarket,
    BuyCreditMarketOnBehalfOfParams,
    BuyCreditMarketParams
} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {Claim, ClaimParams} from "@src/market/libraries/actions/Claim.sol";
import {Deposit, DepositOnBehalfOfParams, DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {
    SetUserConfiguration,
    SetUserConfigurationOnBehalfOfParams,
    SetUserConfigurationParams
} from "@src/market/libraries/actions/SetUserConfiguration.sol";
import {SetVault, SetVaultOnBehalfOfParams, SetVaultParams} from "@src/market/libraries/actions/SetVault.sol";
import {Withdraw, WithdrawOnBehalfOfParams, WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";

import {
    BuyCreditLimit,
    BuyCreditLimitOnBehalfOfParams,
    BuyCreditLimitParams
} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {Liquidate, LiquidateParams} from "@src/market/libraries/actions/Liquidate.sol";

import {ReentrancyGuardUpgradeableWithViewModifier} from "@src/helpers/ReentrancyGuardUpgradeableWithViewModifier.sol";
import {State} from "@src/market/SizeStorage.sol";
import {Multicall} from "@src/market/libraries/Multicall.sol";
import {Compensate, CompensateOnBehalfOfParams, CompensateParams} from "@src/market/libraries/actions/Compensate.sol";
import {PartialRepay, PartialRepayParams} from "@src/market/libraries/actions/PartialRepay.sol";

import {
    CopyLimitOrders,
    CopyLimitOrdersOnBehalfOfParams,
    CopyLimitOrdersParams
} from "@src/market/libraries/actions/CopyLimitOrders.sol";
import {
    LiquidateWithReplacement,
    LiquidateWithReplacementParams
} from "@src/market/libraries/actions/LiquidateWithReplacement.sol";
import {Repay, RepayParams} from "@src/market/libraries/actions/Repay.sol";
import {
    SelfLiquidate,
    SelfLiquidateOnBehalfOfParams,
    SelfLiquidateParams
} from "@src/market/libraries/actions/SelfLiquidate.sol";

import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

import {SizeView} from "@src/market/SizeView.sol";
import {Events} from "@src/market/libraries/Events.sol";

import {IMulticall} from "@src/market/interfaces/IMulticall.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeAdmin} from "@src/market/interfaces/ISizeAdmin.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";
import {ISizeV1_8} from "@src/market/interfaces/v1.8/ISizeV1_8.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {
    BORROW_RATE_UPDATER_ROLE, ISizeFactory, KEEPER_ROLE, PAUSER_ROLE
} from "@src/factory/interfaces/ISizeFactory.sol";

import {UserView} from "@src/market/SizeViewData.sol";
import {ISizeView} from "@src/market/interfaces/ISizeView.sol";

/// @title Size
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISize}.
contract Size is
    ISize,
    SizeView,
    AccessControlUpgradeable,
    PausableUpgradeable,
    /*ReentrancyGuardUpgradeableWithViewModifier,*/
    UUPSUpgradeable
{
    using Initialize for State;
    using UpdateConfig for State;
    using Deposit for State;
    using Withdraw for State;
    using SellCreditMarket for State;
    using SellCreditLimit for State;
    using BuyCreditMarket for State;
    using BuyCreditLimit for State;
    using Repay for State;
    using Claim for State;
    using Liquidate for State;
    using SelfLiquidate for State;
    using LiquidateWithReplacement for State;
    using Compensate for State;
    using PartialRepay for State;
    using SetUserConfiguration for State;
    using RiskLibrary for State;
    using Multicall for State;
    using CopyLimitOrders for State;
    using SetVault for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        InitializeFeeConfigParams calldata f,
        InitializeRiskConfigParams calldata r,
        InitializeOracleParams calldata o,
        InitializeDataParams calldata d
    ) external initializer {
        state.validateInitialize(owner, f, r, o, d);

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(f, r, o, d);
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(KEEPER_ROLE, owner);
        _grantRole(BORROW_RATE_UPDATER_ROLE, owner);
    }

    /// @inheritdoc ISizeV1_8
    function reinitialize() external onlyRole(DEFAULT_ADMIN_ROLE) reinitializer(1_08_00) {
        __ReentrancyGuard_init();
    }

    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        if (hasRole(role, account)) {
            return true;
        } else if (address(state.data.sizeFactory) == address(0)) {
            return false;
        } else {
            return AccessControlUpgradeable(address(state.data.sizeFactory)).hasRole(role, account);
        }
    }

    modifier onlyRoleOrSizeFactoryHasRole(bytes32 role) {
        if (!_hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRoleOrSizeFactoryHasRole(DEFAULT_ADMIN_ROLE)
    {}

    /// @notice Validate that the user has not decreased their collateral ratio
    modifier mustImproveCollateralRatio(address onBehalfOf) {
        uint256 collateralRatioBefore = state.collateralRatio(onBehalfOf);
        _;
        uint256 collateralRatioAfter = state.collateralRatio(onBehalfOf);
        if (collateralRatioAfter <= collateralRatioBefore) {
            revert Errors.MUST_IMPROVE_COLLATERAL_RATIO(onBehalfOf, collateralRatioBefore, collateralRatioAfter);
        }
    }

    /// @inheritdoc ISizeAdmin
    function updateConfig(UpdateConfigParams calldata params)
        external
        override(ISizeAdmin)
        onlyRoleOrSizeFactoryHasRole(DEFAULT_ADMIN_ROLE)
    {
        state.validateUpdateConfig(params);
        state.executeUpdateConfig(params);
    }

    /// @inheritdoc ISizeAdmin
    function setVariablePoolBorrowRate(uint128 borrowRate)
        external
        override(ISizeAdmin)
        nonReentrant
        onlyRoleOrSizeFactoryHasRole(BORROW_RATE_UPDATER_ROLE)
    {
        uint128 oldBorrowRate = state.oracle.variablePoolBorrowRate;
        state.oracle.variablePoolBorrowRate = borrowRate;
        state.oracle.variablePoolBorrowRateUpdatedAt = uint64(block.timestamp);
        emit Events.VariablePoolBorrowRateUpdated(msg.sender, oldBorrowRate, borrowRate);
    }

    /// @inheritdoc ISizeAdmin
    function pause() public override(ISizeAdmin) onlyRoleOrSizeFactoryHasRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc ISizeAdmin
    function unpause() public override(ISizeAdmin) onlyRoleOrSizeFactoryHasRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata _data)
        public
        payable
        override(IMulticall)
        whenNotPaused
        returns (bytes[] memory results)
    {
        results = state.multicall(_data);
    }

    /// @inheritdoc ISize
    function deposit(DepositParams calldata params) public payable override(ISize) {
        depositOnBehalfOf(DepositOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function depositOnBehalfOf(DepositOnBehalfOfParams memory params)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) external payable override(ISize) {
        withdrawOnBehalfOf(WithdrawOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function withdrawOnBehalfOf(WithdrawOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateWithdraw(externalParams);
        state.executeWithdraw(externalParams);
    }

    /// @inheritdoc ISize
    function buyCreditLimit(BuyCreditLimitParams calldata params) external payable override(ISize) {
        buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateBuyCreditLimit(externalParams);
        state.executeBuyCreditLimit(externalParams);
    }

    /// @inheritdoc ISize
    function sellCreditLimit(SellCreditLimitParams calldata params) external payable override(ISize) {
        sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateSellCreditLimit(externalParams);
        state.executeSellCreditLimit(externalParams);
    }

    /// @inheritdoc ISize
    function buyCreditMarket(BuyCreditMarketParams calldata params) external payable override(ISize) {
        buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({params: params, onBehalfOf: msg.sender, recipient: msg.sender})
        );
    }

    /// @inheritdoc ISizeV1_7
    function buyCreditMarketOnBehalfOf(BuyCreditMarketOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateBuyCreditMarket(externalParams);
        state.executeBuyCreditMarket(externalParams);
        if (externalParams.params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(externalParams.params.borrower);
        }
    }

    /// @inheritdoc ISize
    function sellCreditMarket(SellCreditMarketParams memory params) external payable override(ISize) {
        sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({params: params, onBehalfOf: msg.sender, recipient: msg.sender})
        );
    }

    /// @inheritdoc ISizeV1_7
    function sellCreditMarketOnBehalfOf(SellCreditMarketOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateSellCreditMarket(externalParams);
        state.executeSellCreditMarket(externalParams);
        if (externalParams.params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(externalParams.onBehalfOf);
        }
    }

    /// @inheritdoc ISize
    function repay(RepayParams calldata params) external payable override(ISize) nonReentrant whenNotPaused {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISize
    function claim(ClaimParams calldata params) external payable override(ISize) nonReentrant whenNotPaused {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidate(LiquidateParams calldata params)
        external
        payable
        override(ISize)
        nonReentrant
        whenNotPaused
        returns (uint256 liquidatorProfitCollateralToken)
    {
        state.validateLiquidate(params);
        liquidatorProfitCollateralToken = state.executeLiquidate(params);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
    }

    /// @inheritdoc ISize
    function selfLiquidate(SelfLiquidateParams calldata params) external payable override(ISize) {
        selfLiquidateOnBehalfOf(
            SelfLiquidateOnBehalfOfParams({params: params, onBehalfOf: msg.sender, recipient: msg.sender})
        );
    }

    /// @inheritdoc ISizeV1_7
    function selfLiquidateOnBehalfOf(SelfLiquidateOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateSelfLiquidate(externalParams);
        state.executeSelfLiquidate(externalParams);
    }

    /// @inheritdoc ISize
    function liquidateWithReplacement(LiquidateWithReplacementParams calldata params)
        external
        payable
        override(ISize)
        nonReentrant
        whenNotPaused
        onlyRoleOrSizeFactoryHasRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken)
    {
        state.validateLiquidateWithReplacement(params);
        (liquidatorProfitCollateralToken, liquidatorProfitBorrowToken) = state.executeLiquidateWithReplacement(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params) external payable override(ISize) {
        compensateOnBehalfOf(CompensateOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function compensateOnBehalfOf(CompensateOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
        mustImproveCollateralRatio(externalParams.onBehalfOf)
    {
        state.validateCompensate(externalParams);
        state.executeCompensate(externalParams);
    }

    /// @inheritdoc ISize
    function partialRepay(PartialRepayParams calldata params)
        external
        payable
        override(ISize)
        nonReentrant
        whenNotPaused
    {
        state.validatePartialRepay(params);
        state.executePartialRepay(params);
    }

    /// @inheritdoc ISize
    function setUserConfiguration(SetUserConfigurationParams calldata params) external payable override(ISize) {
        setUserConfigurationOnBehalfOf(SetUserConfigurationOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function setUserConfigurationOnBehalfOf(SetUserConfigurationOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateSetUserConfiguration(externalParams);
        state.executeSetUserConfiguration(externalParams);
    }

    /// @inheritdoc ISizeV1_8
    function setVault(SetVaultParams calldata params) external payable override(ISizeV1_8) {
        setVaultOnBehalfOf(SetVaultOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_8
    function setVaultOnBehalfOf(SetVaultOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_8)
        nonReentrant
        whenNotPaused
    {
        state.validateSetVault(externalParams);
        state.executeSetVault(externalParams);
    }

    /// @inheritdoc ISize
    function copyLimitOrders(CopyLimitOrdersParams calldata params) external payable override(ISize) {
        copyLimitOrdersOnBehalfOf(CopyLimitOrdersOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function copyLimitOrdersOnBehalfOf(CopyLimitOrdersOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        nonReentrant
        whenNotPaused
    {
        state.validateCopyLimitOrders(externalParams);
        state.executeCopyLimitOrders(externalParams);
    }
}
