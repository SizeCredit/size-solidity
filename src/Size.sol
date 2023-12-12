// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Initialize, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {BorrowAsMarketOrder, BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";
import {BorrowAsLimitOrder, BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {LendAsLimitOrder, LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrder, LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {Exit, ExitParams} from "@src/libraries/actions/Exit.sol";
import {Repay, RepayParams} from "@src/libraries/actions/Repay.sol";
import {Claim, ClaimParams} from "@src/libraries/actions/Claim.sol";
import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";

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
    using Exit for State;
    using Repay for State;
    using Claim for State;
    using LiquidateLoan for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(InitializeParams calldata params) public initializer {
        state.validateInitialize(params);

        __Ownable_init(params.owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(params);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @inheritdoc ISize
    function deposit(DepositParams calldata params) public override(ISize) {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(WithdrawParams calldata params) public override(ISize) {
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISize
    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) public override(ISize) {
        state.validateLendAsLimitOrder(params);
        state.executeLendAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) public override(ISize) {
        state.validateBorrowAsLimitOrder(params);
        state.executeBorrowAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function lendAsMarketOrder(LendAsMarketOrderParams calldata params) public override(ISize) {
        state.validateLendAsMarketOrder(params);
        state.executeLendAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISize
    function borrowAsMarketOrder(BorrowAsMarketOrderParams calldata params) public override(ISize) {
        state.validateBorrowAsMarketOrder(params);
        state.executeBorrowAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISize
    function exit(ExitParams calldata params) public override(ISize) returns (uint256 amountInLeft) {
        state.validateExit(params);
        amountInLeft = state.executeExit(params);
    }

    /// @inheritdoc ISize
    function repay(RepayParams calldata params) public override(ISize) {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISize
    function claim(ClaimParams calldata params) public override(ISize) {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidateLoan(LiquidateLoanParams calldata params) public override(ISize) returns (uint256 ans) {
        state.validateLiquidateLoan(params);
        ans = state.executeLiquidateLoan(params);
    }
}
