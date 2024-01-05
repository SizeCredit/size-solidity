// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";

import {BorrowAsLimitOrder, BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrder, BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExit, BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {Claim, ClaimParams} from "@src/libraries/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";

import {Initialize, InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {LendAsLimitOrder, LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrder, LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {MoveToVariablePool, MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";
import {UpdateConfig, UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {Common} from "@src/libraries/actions/Common.sol";

import {Compensate, CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {
    LiquidateLoanWithReplacement,
    LiquidateLoanWithReplacementParams
} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoan, SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {SizeView} from "@src/SizeView.sol";

import {State} from "@src/SizeStorage.sol";

import {ISize} from "@src/interfaces/ISize.sol";

contract Size is ISize, SizeView, Initializable, Ownable2StepUpgradeable, MulticallUpgradeable, UUPSUpgradeable {
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
    using MoveToVariablePool for State;
    using Compensate for State;
    using Common for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(InitializeParams calldata params, InitializeExtraParams calldata extraParams)
        external
        initializer
    {
        state.validateInitialize(params, extraParams);

        __Ownable_init(params.owner);
        __Ownable2Step_init();
        __Multicall_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(params, extraParams);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function updateConfig(UpdateConfigParams calldata params) external onlyOwner {
        state.validateUpdateConfig(params);
        state.executeUpdateConfig(params);
    }

    /// @inheritdoc ISize
    function deposit(DepositParams calldata params) external override(ISize) {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) external override(ISize) {
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISize
    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) external override(ISize) {
        state.validateLendAsLimitOrder(params);
        state.executeLendAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) external override(ISize) {
        state.validateBorrowAsLimitOrder(params);
        state.executeBorrowAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function lendAsMarketOrder(LendAsMarketOrderParams calldata params) external override(ISize) {
        state.validateLendAsMarketOrder(params);
        state.executeLendAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISize
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external override(ISize) {
        state.validateBorrowAsMarketOrder(params);
        state.executeBorrowAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISize
    function borrowerExit(BorrowerExitParams calldata params) external override(ISize) {
        state.validateBorrowerExit(params);
        state.executeBorrowerExit(params);
        state.validateUserIsNotLiquidatable(params.borrowerToExitTo);
    }

    /// @inheritdoc ISize
    function repay(RepayParams calldata params) external override(ISize) {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISize
    function claim(ClaimParams calldata params) external override(ISize) {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidateLoan(LiquidateLoanParams calldata params)
        external
        override(ISize)
        returns (uint256 liquidatorProfitCollateralAsset)
    {
        state.validateLiquidateLoan(params);
        liquidatorProfitCollateralAsset = state.executeLiquidateLoan(params);
    }

    /// @inheritdoc ISize
    function selfLiquidateLoan(SelfLiquidateLoanParams calldata params) external override(ISize) {
        state.validateSelfLiquidateLoan(params);
        state.executeSelfLiquidateLoan(params);
    }

    /// @inheritdoc ISize
    function liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams calldata params)
        external
        override(ISize)
        returns (uint256 liquidatorProfitCollateralAsset, uint256 liquidatorProfitBorrowAsset)
    {
        state.validateLiquidateLoanWithReplacement(params);
        (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset) =
            state.executeLiquidateLoanWithReplacement(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISize
    function moveToVariablePool(MoveToVariablePoolParams calldata params) external override(ISize) {
        state.validateMoveToVariablePool(params);
        state.executeMoveToVariablePool(params);
    }

    /// @inheritdoc ISize
    function compensate(CompensateParams calldata params) external override(ISize) {
        state.validateCompensate(params);
        state.executeCompensate(params);
    }
}
