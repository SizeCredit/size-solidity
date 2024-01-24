// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowAsLimitOrder, BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrder, BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExit, BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {Claim, ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {Deposit, DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";

import {LendAsLimitOrder, LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrder, LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateFixedLoan, LiquidateFixedLoanParams} from "@src/libraries/fixed/actions/LiquidateFixedLoan.sol";
import {MoveToVariablePool, MoveToVariablePoolParams} from "@src/libraries/fixed/actions/MoveToVariablePool.sol";

import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";

import {Compensate, CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {
    LiquidateFixedLoanWithReplacement,
    LiquidateFixedLoanWithReplacementParams
} from "@src/libraries/fixed/actions/LiquidateFixedLoanWithReplacement.sol";
import {Repay, RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {
    SelfLiquidateFixedLoan,
    SelfLiquidateFixedLoanParams
} from "@src/libraries/fixed/actions/SelfLiquidateFixedLoan.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {ISizeFixed} from "@src/interfaces/ISizeFixed.sol";

abstract contract SizeFixed is ISizeFixed, SizeStorage {
    using Deposit for State;
    using Withdraw for State;
    using BorrowAsMarketOrder for State;
    using BorrowAsLimitOrder for State;
    using LendAsMarketOrder for State;
    using LendAsLimitOrder for State;
    using BorrowerExit for State;
    using Repay for State;
    using Claim for State;
    using LiquidateFixedLoan for State;
    using SelfLiquidateFixedLoan for State;
    using LiquidateFixedLoanWithReplacement for State;
    using MoveToVariablePool for State;
    using Compensate for State;
    using FixedLibrary for State;

    /// @inheritdoc ISizeFixed
    function deposit(DepositParams calldata params) external override(ISizeFixed) {
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISizeFixed
    function withdraw(WithdrawParams calldata params) external override(ISizeFixed) {
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISizeFixed
    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) external override(ISizeFixed) {
        state.validateLendAsLimitOrder(params);
        state.executeLendAsLimitOrder(params);
    }

    /// @inheritdoc ISizeFixed
    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) external override(ISizeFixed) {
        state.validateBorrowAsLimitOrder(params);
        state.executeBorrowAsLimitOrder(params);
    }

    /// @inheritdoc ISizeFixed
    function lendAsMarketOrder(LendAsMarketOrderParams calldata params) external override(ISizeFixed) {
        state.validateLendAsMarketOrder(params);
        state.executeLendAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISizeFixed
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external override(ISizeFixed) {
        state.validateBorrowAsMarketOrder(params);
        state.executeBorrowAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(msg.sender);
    }

    /// @inheritdoc ISizeFixed
    function borrowerExit(BorrowerExitParams calldata params) external override(ISizeFixed) {
        state.validateBorrowerExit(params);
        state.executeBorrowerExit(params);
        state.validateUserIsNotLiquidatable(params.borrowerToExitTo);
    }

    /// @inheritdoc ISizeFixed
    function repay(RepayParams calldata params) external override(ISizeFixed) {
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISizeFixed
    function claim(ClaimParams calldata params) external override(ISizeFixed) {
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISizeFixed
    function liquidateFixedLoan(LiquidateFixedLoanParams calldata params)
        external
        override(ISizeFixed)
        returns (uint256 liquidatorProfitCollateralAsset)
    {
        state.validateLiquidateFixedLoan(params);
        liquidatorProfitCollateralAsset = state.executeLiquidateFixedLoan(params);
    }

    /// @inheritdoc ISizeFixed
    function selfLiquidateFixedLoan(SelfLiquidateFixedLoanParams calldata params) external override(ISizeFixed) {
        state.validateSelfLiquidateFixedLoan(params);
        state.executeSelfLiquidateFixedLoan(params);
    }

    /// @inheritdoc ISizeFixed
    function liquidateFixedLoanWithReplacement(LiquidateFixedLoanWithReplacementParams calldata params)
        external
        override(ISizeFixed)
        returns (uint256 liquidatorProfitCollateralAsset, uint256 liquidatorProfitBorrowAsset)
    {
        state.validateLiquidateFixedLoanWithReplacement(params);
        (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset) =
            state.executeLiquidateFixedLoanWithReplacement(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISizeFixed
    function moveToVariablePool(MoveToVariablePoolParams calldata params) external override(ISizeFixed) {
        state.validateMoveToVariablePool(params);
        state.executeMoveToVariablePool(params);
    }

    /// @inheritdoc ISizeFixed
    function compensate(CompensateParams calldata params) external override(ISizeFixed) {
        state.validateCompensate(params);
        state.executeCompensate(params);
    }
}
