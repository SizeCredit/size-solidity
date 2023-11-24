// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

// import {console2 as console} from "forge-std/console2.sol";

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
import {LiquidateBorrower, LiquidateBorrowerParams} from "@src/libraries/actions/LiquidateBorrower.sol";
import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";

import {SizeView} from "@src/SizeView.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {OfferLibrary, LoanOffer, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {Math, PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

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
    using LiquidateBorrower for State;
    using LiquidateLoan for State;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _priceFeed,
        uint256 _CROpening,
        uint256 _CRLiquidation,
        uint256 _collateralPercentagePremiumToLiquidator,
        uint256 _collateralPercentagePremiumToBorrower
    ) public initializer {
        InitializeParams memory params = InitializeParams({
            owner: _owner,
            priceFeed: _priceFeed,
            CROpening: _CROpening,
            CRLiquidation: _CRLiquidation,
            collateralPercentagePremiumToLiquidator: _collateralPercentagePremiumToLiquidator,
            collateralPercentagePremiumToBorrower: _collateralPercentagePremiumToBorrower
        });
        state.validateInitialize(params);

        __Ownable_init(params.owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        state.executeInitialize(params);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @inheritdoc ISize
    function deposit(uint256 cash, uint256 eth) public override(ISize) {
        DepositParams memory params = DepositParams({user: msg.sender, cash: cash, eth: eth});
        state.validateDeposit(params);
        state.executeDeposit(params);
    }

    /// @inheritdoc ISize
    function withdraw(uint256 cash, uint256 eth) public override(ISize) {
        WithdrawParams memory params = WithdrawParams({user: msg.sender, cash: cash, eth: eth});
        state.validateWithdraw(params);
        state.executeWithdraw(params);
        state.validateUserIsNotLiquidatable(params.user);
    }

    /// @inheritdoc ISize
    function lendAsLimitOrder(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256[] calldata timeBuckets,
        uint256[] calldata rates
    ) public override(ISize) {
        LendAsLimitOrderParams memory params = LendAsLimitOrderParams({
            lender: msg.sender,
            maxAmount: maxAmount,
            maxDueDate: maxDueDate,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        state.validateLendAsLimitOrder(params);
        state.executeLendAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function borrowAsLimitOrder(uint256 maxAmount, uint256[] calldata timeBuckets, uint256[] calldata rates)
        public
        override(ISize)
    {
        BorrowAsLimitOrderParams memory params = BorrowAsLimitOrderParams({
            borrower: msg.sender,
            maxAmount: maxAmount,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        state.validateBorrowAsLimitOrder(params);
        state.executeBorrowAsLimitOrder(params);
    }

    /// @inheritdoc ISize
    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount) public override(ISize) {
        LendAsMarketOrderParams memory params =
            LendAsMarketOrderParams({lender: msg.sender, borrower: borrower, dueDate: dueDate, amount: amount});
        state.validateLendAsMarketOrder(params);
        state.executeLendAsMarketOrder(params);
    }

    /// @inheritdoc ISize
    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoansIds
    ) public override(ISize) {
        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            borrower: msg.sender,
            lender: lender,
            amount: amount,
            dueDate: dueDate,
            virtualCollateralLoansIds: virtualCollateralLoansIds
        });

        state.validateBorrowAsMarketOrder(params);
        state.executeBorrowAsMarketOrder(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISize
    function exit(uint256 loanId, uint256 amount, uint256 dueDate, address[] memory lendersToExitTo)
        public
        override(ISize)
        returns (uint256 amountInLeft)
    {
        ExitParams memory params = ExitParams({
            exiter: msg.sender,
            loanId: loanId,
            amount: amount,
            dueDate: dueDate,
            lendersToExitTo: lendersToExitTo
        });

        state.validateExit(params);
        amountInLeft = state.executeExit(params);
    }

    /// @inheritdoc ISize
    function repay(uint256 loanId, uint256 amount) public override(ISize) {
        RepayParams memory params = RepayParams({loanId: loanId, amount: amount});
        state.validateRepay(params);
        state.executeRepay(params);
    }

    /// @inheritdoc ISize
    function claim(uint256 loanId) public override(ISize) {
        ClaimParams memory params = ClaimParams({loanId: loanId, lender: msg.sender, protocol: address(this)});
        state.validateClaim(params);
        state.executeClaim(params);
    }

    /// @inheritdoc ISize
    function liquidateBorrower(address borrower)
        public
        override(ISize)
        returns (uint256 actualAmountETH, uint256 targetAmountETH)
    {
        LiquidateBorrowerParams memory params = LiquidateBorrowerParams({borrower: borrower, liquidator: msg.sender});
        state.validateLiquidateBorrower(params);
        (actualAmountETH, targetAmountETH) = state.executeLiquidateBorrower(params);
        state.validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISize
    function liquidateLoan(uint256 loanId) public override(ISize) {
        LiquidateLoanParams memory params = LiquidateLoanParams({loanId: loanId, liquidator: msg.sender});
        state.validateLiquidateLoan(params);
        state.executeLiquidateLoan(params);
    }
}
