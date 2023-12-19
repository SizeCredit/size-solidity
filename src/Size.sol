// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {BorrowAsLimitOrder, BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrder, BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExit, BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {Claim, ClaimParams} from "@src/libraries/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";
import {Initialize, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {LendAsLimitOrder, LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrder, LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LenderExit, LenderExitParams} from "@src/libraries/actions/LenderExit.sol";
import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {
    LiquidateLoanWithReplacement,
    LiquidateLoanWithReplacementParams
} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoan, SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {SizeView} from "@src/SizeView.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {ISize} from "@src/interfaces/ISize.sol";

contract Size is ISize, SizeView, Initializable, Ownable2StepUpgradeable, UUPSUpgradeable {
    using Initialize for State;
    using Deposit for State;
    using Withdraw for State;
    using BorrowAsMarketOrder for State;
    using BorrowAsLimitOrder for State;
    using LendAsMarketOrder for State;
    using LendAsLimitOrder for State;
    using LenderExit for State;
    using BorrowerExit for State;
    using Repay for State;
    using Claim for State;
    using LiquidateLoan for State;
    using SelfLiquidateLoan for State;
    using LiquidateLoanWithReplacement for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(InitializeParams calldata params) external initializer {
        state.validateInitialize(params);

        __Ownable_init(params.owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(params);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
    function lenderExit(LenderExitParams calldata params) external override(ISize) returns (uint256 amountInLeft) {
        state.validateLenderExit(params);
        amountInLeft = state.executeLenderExit(params);
    }

    /// @inheritdoc ISize
    function borrowerExit(BorrowerExitParams calldata params) external override(ISize) returns (uint256 ans) {
        state.validateBorrowerExit(params);
        ans = state.executeBorrowerExit(params);
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
        returns (uint256 liquidatorProfitBorrowAsset)
    {
        state.validateLiquidateLoanWithReplacement(params);
        liquidatorProfitBorrowAsset = state.executeLiquidateLoanWithReplacement(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }
}
