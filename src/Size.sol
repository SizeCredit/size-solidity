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
import {Deposit, DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";

import {LendAsLimitOrder, LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrder, LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/fixed/actions/LiquidateLoan.sol";

import {Compensate, CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {
    LiquidateLoanWithReplacement,
    LiquidateLoanWithReplacementParams
} from "@src/libraries/fixed/actions/LiquidateLoanWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateLoan, SelfLiquidateLoanParams} from "@src/libraries/fixed/actions/SelfLiquidateLoan.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {CapsLibrary} from "@src/libraries/fixed/CapsLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {SizeView} from "@src/SizeView.sol";

import {State} from "@src/SizeStorage.sol";

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
    using LiquidateLoan for State;
    using SelfLiquidateLoan for State;
    using LiquidateLoanWithReplacement for State;
    using Compensate for State;
    using RiskLibrary for State;
    using CapsLibrary for State;

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
        state.validateUserIsNotBelowRiskCR(msg.sender);
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
        state.validateUserIsNotBelowRiskCR(params.borrower);
        state.validateDebtTokenCap();
    }

    /// @inheritdoc ISize
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external override(ISize) whenNotPaused {
        state.validateBorrowAsMarketOrder(params);
        state.executeBorrowAsMarketOrder(params);
        state.validateUserIsNotBelowRiskCR(msg.sender);
        state.validateDebtTokenCap();
    }

    /// @inheritdoc ISize
    function borrowerExit(BorrowerExitParams calldata params) external override(ISize) whenNotPaused {
        state.validateBorrowerExit(params);
        state.executeBorrowerExit(params);
        state.validateUserIsNotBelowRiskCR(params.borrowerToExitTo);
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
    function liquidateLoan(LiquidateLoanParams calldata params)
        external
        override(ISize)
        whenNotPaused
        returns (uint256 liquidatorProfitCollateralAsset)
    {
        state.validateLiquidateLoan(params);
        liquidatorProfitCollateralAsset = state.executeLiquidateLoan(params);
    }

    /// @inheritdoc ISize
    function selfLiquidateLoan(SelfLiquidateLoanParams calldata params) external override(ISize) whenNotPaused {
        state.validateSelfLiquidateLoan(params);
        state.executeSelfLiquidateLoan(params);
    }

    /// @inheritdoc ISize
    function liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams calldata params)
        external
        override(ISize)
        whenNotPaused
        onlyRole(KEEPER_ROLE)
        returns (uint256 liquidatorProfitCollateralAsset, uint256 liquidatorProfitBorrowAsset)
    {
        state.validateLiquidateLoanWithReplacement(params);
        (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset) =
            state.executeLiquidateLoanWithReplacement(params);
        state.validateUserIsNotBelowRiskCR(params.borrower);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params) external override(ISize) whenNotPaused {
        state.validateCompensate(params);
        state.executeCompensate(params);
    }
}
