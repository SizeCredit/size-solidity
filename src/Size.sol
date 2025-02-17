// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {
    SellCreditLimit,
    SellCreditLimitOnBehalfOfParams,
    SellCreditLimitParams
} from "@src/libraries/actions/SellCreditLimit.sol";
import {
    SellCreditMarket,
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams
} from "@src/libraries/actions/SellCreditMarket.sol";

import {
    BuyCreditMarket,
    BuyCreditMarketOnBehalfOfParams,
    BuyCreditMarketParams
} from "@src/libraries/actions/BuyCreditMarket.sol";
import {Claim, ClaimParams} from "@src/libraries/actions/Claim.sol";
import {Deposit, DepositOnBehalfOfParams, DepositParams} from "@src/libraries/actions/Deposit.sol";
import {
    SetUserConfiguration,
    SetUserConfigurationOnBehalfOfParams,
    SetUserConfigurationParams
} from "@src/libraries/actions/SetUserConfiguration.sol";
import {Withdraw, WithdrawOnBehalfOfParams, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {
    BuyCreditLimit,
    BuyCreditLimitOnBehalfOfParams,
    BuyCreditLimitParams
} from "@src/libraries/actions/BuyCreditLimit.sol";
import {Liquidate, LiquidateParams} from "@src/libraries/actions/Liquidate.sol";

import {State} from "@src/SizeStorage.sol";
import {Multicall} from "@src/libraries/Multicall.sol";
import {Compensate, CompensateOnBehalfOfParams, CompensateParams} from "@src/libraries/actions/Compensate.sol";

import {
    CopyLimitOrders,
    CopyLimitOrdersOnBehalfOfParams,
    CopyLimitOrdersParams
} from "@src/libraries/actions/CopyLimitOrders.sol";
import {
    LiquidateWithReplacement,
    LiquidateWithReplacementParams
} from "@src/libraries/actions/LiquidateWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/actions/Repay.sol";
import {
    SelfLiquidate, SelfLiquidateOnBehalfOfParams, SelfLiquidateParams
} from "@src/libraries/actions/SelfLiquidate.sol";

import {CapsLibrary} from "@src/libraries/CapsLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {SizeView} from "@src/SizeView.sol";
import {Events} from "@src/libraries/Events.sol";

import {IMulticall} from "@src/interfaces/IMulticall.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeAdmin} from "@src/interfaces/ISizeAdmin.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";

bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 constant BORROW_RATE_UPDATER_ROLE = keccak256("BORROW_RATE_UPDATER_ROLE");

/// @title Size
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISize}.
contract Size is ISize, SizeView, Initializable, AccessControlUpgradeable, PausableUpgradeable, UUPSUpgradeable {
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
    using SetUserConfiguration for State;
    using RiskLibrary for State;
    using CapsLibrary for State;
    using Multicall for State;
    using CopyLimitOrders for State;

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
        __UUPSUpgradeable_init();

        state.executeInitialize(f, r, o, d);
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(KEEPER_ROLE, owner);
        _grantRole(BORROW_RATE_UPDATER_ROLE, owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Validate that the user has not put themselves in underwater state
    modifier shouldNotEndUpUnderwater(address onBehalfOf) {
        bool isUserUnderwaterBefore = state.isUserUnderwater(onBehalfOf);
        _;
        bool isUserUnderwaterAfter = state.isUserUnderwater(onBehalfOf);
        if (!isUserUnderwaterBefore && isUserUnderwaterAfter) {
            revert Errors.USER_IS_UNDERWATER(onBehalfOf, state.collateralRatio(onBehalfOf));
        }
    }

    /// @inheritdoc ISizeAdmin
    function updateConfig(UpdateConfigParams calldata params)
        external
        override(ISizeAdmin)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        state.validateUpdateConfig(params);
        state.executeUpdateConfig(params);
    }

    /// @inheritdoc ISizeAdmin
    function setVariablePoolBorrowRate(uint128 borrowRate)
        external
        override(ISizeAdmin)
        onlyRole(BORROW_RATE_UPDATER_ROLE)
    {
        uint128 oldBorrowRate = state.oracle.variablePoolBorrowRate;
        state.oracle.variablePoolBorrowRate = borrowRate;
        state.oracle.variablePoolBorrowRateUpdatedAt = uint64(block.timestamp);
        emit Events.VariablePoolBorrowRateUpdated(msg.sender, oldBorrowRate, borrowRate);
    }

    /// @inheritdoc ISizeAdmin
    function pause() public override(ISizeAdmin) onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc ISizeAdmin
    function unpause() public override(ISizeAdmin) onlyRole(PAUSER_ROLE) {
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
    function deposit(DepositParams calldata params) public payable override(ISize) whenNotPaused {
        depositOnBehalfOf(DepositOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function depositOnBehalfOf(DepositOnBehalfOfParams memory params)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) external payable override(ISize) whenNotPaused {
        withdrawOnBehalfOf(WithdrawOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function withdrawOnBehalfOf(WithdrawOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateWithdraw(externalParams);
        state.executeWithdraw(externalParams);
    }

    /// @inheritdoc ISize
    function buyCreditLimit(BuyCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function buyCreditLimitOnBehalfOf(BuyCreditLimitOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateBuyCreditLimit(externalParams);
        state.executeBuyCreditLimit(externalParams);
    }

    /// @inheritdoc ISize
    function sellCreditLimit(SellCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function sellCreditLimitOnBehalfOf(SellCreditLimitOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateSellCreditLimit(externalParams);
        state.executeSellCreditLimit(externalParams);
    }

    /// @inheritdoc ISize
    function buyCreditMarket(BuyCreditMarketParams calldata params) external payable override(ISize) whenNotPaused {
        buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({params: params, onBehalfOf: msg.sender, recipient: msg.sender})
        );
    }

    /// @inheritdoc ISizeV1_7
    function buyCreditMarketOnBehalfOf(BuyCreditMarketOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateBuyCreditMarket(externalParams);
        uint256 amount = state.executeBuyCreditMarket(externalParams);
        if (externalParams.params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(externalParams.params.borrower);
        }
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function sellCreditMarket(SellCreditMarketParams memory params) external payable override(ISize) whenNotPaused {
        sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({params: params, onBehalfOf: msg.sender, recipient: msg.sender})
        );
    }

    /// @inheritdoc ISizeV1_7
    function sellCreditMarketOnBehalfOf(SellCreditMarketOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateSellCreditMarket(externalParams);
        uint256 amount = state.executeSellCreditMarket(externalParams);
        if (externalParams.params.creditPositionId == RESERVED_ID) {
            state.validateUserIsNotBelowOpeningLimitBorrowCR(externalParams.onBehalfOf);
        }
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function repay(RepayParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISize
    function claim(ClaimParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidate(LiquidateParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        returns (uint256 liquidatorProfitCollateralToken)
    {
        state.validateLiquidate(params);
        liquidatorProfitCollateralToken = state.executeLiquidate(params);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
    }

    /// @inheritdoc ISize
    function selfLiquidate(SelfLiquidateParams calldata params) external payable override(ISize) whenNotPaused {
        selfLiquidateOnBehalfOf(
            SelfLiquidateOnBehalfOfParams({params: params, onBehalfOf: msg.sender, recipient: msg.sender})
        );
    }

    /// @inheritdoc ISizeV1_7
    function selfLiquidateOnBehalfOf(SelfLiquidateOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
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
        whenNotPaused
        onlyRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken)
    {
        state.validateLiquidateWithReplacement(params);
        uint256 amount;
        (amount, liquidatorProfitCollateralToken, liquidatorProfitBorrowToken) =
            state.executeLiquidateWithReplacement(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralToken);
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        shouldNotEndUpUnderwater(msg.sender)
    {
        compensateOnBehalfOf(CompensateOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function compensateOnBehalfOf(CompensateOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
        shouldNotEndUpUnderwater(externalParams.onBehalfOf)
    {
        state.validateCompensate(externalParams);
        state.executeCompensate(externalParams);
    }

    /// @inheritdoc ISize
    function setUserConfiguration(SetUserConfigurationParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
    {
        setUserConfigurationOnBehalfOf(SetUserConfigurationOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    /// @inheritdoc ISizeV1_7
    function setUserConfigurationOnBehalfOf(SetUserConfigurationOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateSetUserConfiguration(externalParams);
        state.executeSetUserConfiguration(externalParams);
    }

    /// @inheritdoc ISize
    function copyLimitOrders(CopyLimitOrdersParams calldata params) external payable override(ISize) whenNotPaused {
        copyLimitOrdersOnBehalfOf(CopyLimitOrdersOnBehalfOfParams({params: params, onBehalfOf: msg.sender}));
    }

    function copyLimitOrdersOnBehalfOf(CopyLimitOrdersOnBehalfOfParams memory externalParams)
        public
        payable
        override(ISizeV1_7)
        whenNotPaused
    {
        state.validateCopyLimitOrders(externalParams);
        state.executeCopyLimitOrders(externalParams);
    }
}
