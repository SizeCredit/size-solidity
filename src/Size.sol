// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/general/actions/Initialize.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

import {SellCreditLimit, SellCreditLimitParams} from "@src/libraries/fixed/actions/SellCreditLimit.sol";
import {SellCreditMarket, SellCreditMarketParams} from "@src/libraries/fixed/actions/SellCreditMarket.sol";

import {Claim, ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/general/actions/Deposit.sol";

import {BuyCreditMarket, BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {SetUserConfiguration, SetUserConfigurationParams} from "@src/libraries/fixed/actions/SetUserConfiguration.sol";

import {BuyCreditLimit, BuyCreditLimitParams} from "@src/libraries/fixed/actions/BuyCreditLimit.sol";
import {Liquidate, LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {Multicall} from "@src/libraries/Multicall.sol";
import {Compensate, CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {
    LiquidateWithReplacement,
    LiquidateWithReplacementParams
} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidate, SelfLiquidateParams} from "@src/libraries/fixed/actions/SelfLiquidate.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {State} from "@src/SizeStorage.sol";

import {CapsLibrary} from "@src/libraries/fixed/CapsLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {SizeView} from "@src/SizeView.sol";

import {ISize} from "@src/interfaces/ISize.sol";

bytes32 constant KEEPER_ROLE = "KEEPER_ROLE";
bytes32 constant PAUSER_ROLE = "PAUSER_ROLE";

/// @title Size
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
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function updateConfig(UpdateConfigParams calldata params) external onlyRole(DEFAULT_ADMIN_ROLE) {
        state.validateUpdateConfig(params);
        state.executeUpdateConfig(params);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function multicall(bytes[] calldata _data)
        public
        payable
        override(ISize)
        whenNotPaused
        returns (bytes[] memory results)
    {
        results = state.multicall(_data);
    }

    /// @inheritdoc ISize
    function deposit(DepositParams calldata params) public payable override(ISize) whenNotPaused {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(msg.sender);
    }

    /// @inheritdoc ISize
    function buyCreditLimitOrder(BuyCreditLimitParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateBuyCreditLimit(params);
        state.executeBuyCreditLimit(params);
    }

    /// @inheritdoc ISize
    function sellCreditLimitOrder(SellCreditLimitParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
    {
        state.validateSellCreditLimit(params);
        state.executeSellCreditLimit(params);
    }

    /// @inheritdoc ISize
    function sellCreditMarket(SellCreditMarketParams memory params) external payable override(ISize) whenNotPaused {
        state.validateSellCreditMarket(params);
        uint256 amount = state.executeSellCreditMarket(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(msg.sender);
        state.validateDebtTokenCap();
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
        returns (uint256 liquidatorProfitCollateralAsset)
    {
        state.validateLiquidate(params);
        liquidatorProfitCollateralAsset = state.executeLiquidate(params);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralAsset);
    }

    /// @inheritdoc ISize
    function selfLiquidate(SelfLiquidateParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateSelfLiquidate(params);
        state.executeSelfLiquidate(params);
    }

    /// @inheritdoc ISize
    function liquidateWithReplacement(LiquidateWithReplacementParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
        onlyRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralAsset, uint256 liquidatorProfitBorrowAsset)
    {
        state.validateLiquidateWithReplacement(params);
        uint256 amount;
        (amount, liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset) =
            state.executeLiquidateWithReplacement(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralAsset);
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateCompensate(params);
        state.executeCompensate(params);
        state.validateUserIsNotUnderwater(msg.sender);
    }

    /// @inheritdoc ISize
    function setUserConfiguration(SetUserConfigurationParams calldata params)
        external
        payable
        override(ISize)
        whenNotPaused
    {
        state.validateSetUserConfiguration(params);
        state.executeSetUserConfiguration(params);
    }

    /// @inheritdoc ISize
    function buyCreditMarket(BuyCreditMarketParams calldata params) external payable override(ISize) whenNotPaused {
        state.validateBuyCreditMarket(params);
        uint256 amount = state.executeBuyCreditMarket(params);
        state.validateUserIsNotBelowOpeningLimitBorrowCR(params.borrower);
        state.validateDebtTokenCap();
        state.validateVariablePoolHasEnoughLiquidity(amount);
    }
}
