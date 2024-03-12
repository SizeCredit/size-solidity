// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {
    Initialize,
    InitializeConfigParams,
    InitializeDataParams,
    InitializeOracleParams
} from "@src/libraries/general/actions/Initialize.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

import {BorrowAsLimitOrder, BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrder, BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExit, BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {Claim, ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/general/actions/Deposit.sol";

import {LendAsLimitOrder, LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrder, LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {Liquidate, LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

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

import {BorrowVariable, BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {RepayVariable, RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";
import {LiquidateVariable, LiquidateVariableParams} from "@src/libraries/variable/actions/LiquidateVariable.sol";

import {SizeView} from "@src/SizeView.sol";

import {ISize} from "@src/interfaces/ISize.sol";

/// @title Size
/// @notice See the documentation in {ISize}.
contract Size is
    ISize,
    SizeView,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    MulticallUpgradeable,
    UUPSUpgradeable
{
    // @audit Check if borrower == lender == liquidator may cause any issues
    using Initialize for State;
    using UpdateConfig for State;
    using Deposit for State;
    using Withdraw for State;
    using BorrowAsMarketOrder for State;
    using BorrowAsLimitOrder for State;
    using LendAsMarketOrder for State;
    using LendAsLimitOrder for State;
    using BorrowerExit for State;
    using Repay for State;
    using Claim for State;
    using Liquidate for State;
    using SelfLiquidate for State;
    using LiquidateWithReplacement for State;
    using Compensate for State;
    using RiskLibrary for State;
    using CapsLibrary for State;
    using BorrowVariable for State;
    using RepayVariable for State;
    using LiquidateVariable for State;

    bytes32 public constant KEEPER_ROLE = "KEEPER_ROLE";
    bytes32 public constant PAUSER_ROLE = "PAUSER_ROLE";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        InitializeConfigParams calldata c,
        InitializeOracleParams calldata o,
        InitializeDataParams calldata d
    ) external initializer {
        state.validateInitialize(owner, c, o, d);

        __AccessControl_init();
        __Pausable_init();
        __Multicall_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(c, o, d);
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSER_ROLE, owner);
        _grantRole(KEEPER_ROLE, owner);
    }

    // solhint-disable-next-line no-empty-blocks
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

    /// @inheritdoc ISize
    function deposit(DepositParams calldata params) external override(ISize) whenNotPaused {
        state.validateDeposit(params);
        state.executeDeposit(params);
        state.validateCollateralTokenCap();
        state.validateBorrowATokenCap();
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) external override(ISize) whenNotPaused {
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotBelowopeningLimitBorrowCR(msg.sender);
    }

    /// @inheritdoc ISize
    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) external override(ISize) whenNotPaused {
        state.validateLendAsLimitOrder(params);
        state.executeLendAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) external override(ISize) whenNotPaused {
        state.validateBorrowAsLimitOrder(params);
        state.executeBorrowAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function lendAsMarketOrder(LendAsMarketOrderParams calldata params) external override(ISize) whenNotPaused {
        state.validateLendAsMarketOrder(params);
        state.executeLendAsMarketOrder(params);
        state.validateUserIsNotBelowopeningLimitBorrowCR(params.borrower);
        state.validateDebtTokenCap();
        state.validateVariablePoolHasEnoughLiquidity();
    }

    /// @inheritdoc ISize
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external override(ISize) whenNotPaused {
        state.validateBorrowAsMarketOrder(params);
        state.executeBorrowAsMarketOrder(params);
        state.validateUserIsNotBelowopeningLimitBorrowCR(msg.sender);
        state.validateDebtTokenCap();
        state.validateVariablePoolHasEnoughLiquidity();
    }

    /// @inheritdoc ISize
    function borrowerExit(BorrowerExitParams calldata params) external override(ISize) whenNotPaused {
        state.validateBorrowerExit(params);
        state.executeBorrowerExit(params);
        state.validateUserIsNotBelowopeningLimitBorrowCR(params.borrowerToExitTo);
        state.validateVariablePoolHasEnoughLiquidity();
    }

    /// @inheritdoc ISize
    function repay(RepayParams calldata params) external override(ISize) whenNotPaused {
        state.validateRepay(params);
        state.executeRepay(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISize
    function claim(ClaimParams calldata params) external override(ISize) whenNotPaused {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidate(LiquidateParams calldata params)
        external
        override(ISize)
        whenNotPaused
        returns (uint256 liquidatorProfitCollateralAsset)
    {
        state.validateLiquidate(params);
        liquidatorProfitCollateralAsset = state.executeLiquidate(params);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralAsset);
    }

    /// @inheritdoc ISize
    function selfLiquidate(SelfLiquidateParams calldata params) external override(ISize) whenNotPaused {
        state.validateSelfLiquidate(params);
        state.executeSelfLiquidate(params);
    }

    /// @inheritdoc ISize
    function liquidateWithReplacement(LiquidateWithReplacementParams calldata params)
        external
        override(ISize)
        whenNotPaused
        onlyRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralAsset, uint256 liquidatorProfitBorrowAsset)
    {
        state.validateLiquidateWithReplacement(params);
        (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset) = state.executeLiquidateWithReplacement(params);
        state.validateUserIsNotBelowopeningLimitBorrowCR(params.borrower);
        state.validateMinimumCollateralProfit(params, liquidatorProfitCollateralAsset);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params) external override(ISize) whenNotPaused {
        state.validateCompensate(params);
        state.executeCompensate(params);
        state.validateUserIsNotBelowopeningLimitBorrowCR(msg.sender);
    }

    /// @inheritdoc ISize
    function variablePoolAllowlisted(address account) external view override(ISize) whenNotPaused returns (bool) {
        return state.data.variablePoolAllowlisted[account];
    }

    /// @inheritdoc ISize
    function borrowVariable(BorrowVariableParams calldata params) external override(ISize) whenNotPaused {
        state.validateBorrowVariable(params);
        state.executeBorrowVariable(params);
    }

    /// @inheritdoc ISize
    function repayVariable(RepayVariableParams calldata params) external override(ISize) whenNotPaused {
        state.validateRepayVariable(params);
        state.executeRepayVariable(params);
    }

    /// @inheritdoc ISize
    function liquidateVariable(LiquidateVariableParams calldata params) external override(ISize) whenNotPaused {
        state.validateLiquidateVariable(params);
        state.executeLiquidateVariable(params);
    }
}
