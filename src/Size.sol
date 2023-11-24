// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {SizeInitialize, SizeInitializeParams} from "./SizeInitialize.sol";
import {SizeBorrowAsMarketOrder, BorrowAsMarketOrderParams} from "./SizeBorrowAsMarketOrder.sol";
import {SizeBorrowAsLimitOrder, BorrowAsLimitOrderParams} from "./SizeBorrowAsLimitOrder.sol";
import {SizeLendAsLimitOrder, LendAsLimitOrderParams} from "./SizeLendAsLimitOrder.sol";
import {SizeLendAsMarketOrder, LendAsMarketOrderParams} from "./SizeLendAsMarketOrder.sol";
import {SizeExit, ExitParams} from "@src/SizeExit.sol";
import {SizeRepay, RepayParams} from "@src/SizeRepay.sol";
import {SizeClaim, ClaimParams} from "@src/SizeClaim.sol";
import {SizeLiquidateBorrower, LiquidateBorrowerParams} from "@src/SizeLiquidateBorrower.sol";
import {SizeLiquidateLoan, LiquidateLoanParams} from "@src/SizeLiquidateLoan.sol";
import {SizeDeposit, DepositParams} from "@src/SizeDeposit.sol";
import {SizeWithdraw, WithdrawParams} from "@src/SizeWithdraw.sol";

import {YieldCurve} from "./libraries/YieldCurveLibrary.sol";
import {OfferLibrary, LoanOffer, BorrowOffer} from "./libraries/OfferLibrary.sol";
import {UserLibrary, User} from "./libraries/UserLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {Math, PERCENT} from "./libraries/MathLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";

import {IPriceFeed} from "./oracle/IPriceFeed.sol";

import {ISize} from "./interfaces/ISize.sol";
import {ISizeFunctions} from "./interfaces/ISizeFunctions.sol";

contract Size is
    ISize,
    SizeInitialize,
    SizeDeposit,
    SizeWithdraw,
    SizeBorrowAsMarketOrder,
    SizeBorrowAsLimitOrder,
    SizeLendAsMarketOrder,
    SizeLendAsLimitOrder,
    SizeExit,
    SizeRepay,
    SizeClaim,
    SizeLiquidateBorrower,
    SizeLiquidateLoan,
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];
    using UserLibrary for User;

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
        SizeInitializeParams memory params = SizeInitializeParams({
            owner: _owner,
            priceFeed: _priceFeed,
            CROpening: _CROpening,
            CRLiquidation: _CRLiquidation,
            collateralPercentagePremiumToLiquidator: _collateralPercentagePremiumToLiquidator,
            collateralPercentagePremiumToBorrower: _collateralPercentagePremiumToBorrower
        });
        _validateInitialize(params);

        __Ownable_init(params.owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        _executeInitialize(params);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @inheritdoc ISizeFunctions
    function deposit(uint256 cash, uint256 eth) public override(ISizeFunctions) {
        DepositParams memory params = DepositParams({user: msg.sender, cash: cash, eth: eth});
        _validateDeposit(params);
        _executeDeposit(params);
    }

    /// @inheritdoc ISizeFunctions
    function withdraw(uint256 cash, uint256 eth) public override(ISizeFunctions) {
        WithdrawParams memory params = WithdrawParams({user: msg.sender, cash: cash, eth: eth});
        _validateWithdraw(params);
        _executeWithdraw(params);
        _validateUserIsNotLiquidatable(params.user);
    }

    /// @inheritdoc ISizeFunctions
    function lendAsLimitOrder(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256[] calldata timeBuckets,
        uint256[] calldata rates
    ) public override(ISizeFunctions) {
        LendAsLimitOrderParams memory params = LendAsLimitOrderParams({
            lender: msg.sender,
            maxAmount: maxAmount,
            maxDueDate: maxDueDate,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        _validateLendAsLimitOrder(params);
        _executeLendAsLimitOrder(params);
    }

    /// @inheritdoc ISizeFunctions
    function borrowAsLimitOrder(uint256 maxAmount, uint256[] calldata timeBuckets, uint256[] calldata rates)
        public
        override(ISizeFunctions)
    {
        BorrowAsLimitOrderParams memory params = BorrowAsLimitOrderParams({
            borrower: msg.sender,
            maxAmount: maxAmount,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        _validateBorrowAsLimitOrder(params);
        _executeBorrowAsLimitOrder(params);
    }

    /// @inheritdoc ISizeFunctions
    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount) public override(ISizeFunctions) {
        LendAsMarketOrderParams memory params =
            LendAsMarketOrderParams({lender: msg.sender, borrower: borrower, dueDate: dueDate, amount: amount});
        _validateLendAsMarketOrder(params);
        _executeLendAsMarketOrder(params);
    }

    /// @inheritdoc ISizeFunctions
    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoansIds
    ) public override(ISizeFunctions) {
        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            borrower: msg.sender,
            lender: lender,
            amount: amount,
            dueDate: dueDate,
            virtualCollateralLoansIds: virtualCollateralLoansIds
        });

        _validateBorrowAsMarketOrder(params);
        _executeBorrowAsMarketOrder(params);
        _validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISizeFunctions
    function exit(uint256 loanId, uint256 amount, uint256 dueDate, address[] memory lendersToExitTo)
        public
        override(ISizeFunctions)
        returns (uint256 amountInLeft)
    {
        ExitParams memory params = ExitParams({
            exiter: msg.sender,
            loanId: loanId,
            amount: amount,
            dueDate: dueDate,
            lendersToExitTo: lendersToExitTo
        });

        _validateExit(params);
        amountInLeft = _executeExit(params);
    }

    /// @inheritdoc ISizeFunctions
    function repay(uint256 loanId, uint256 amount) public override(ISizeFunctions) {
        RepayParams memory params = RepayParams({loanId: loanId, amount: amount});
        _validateRepay(params);
        _executeRepay(params);
    }

    /// @inheritdoc ISizeFunctions
    function claim(uint256 loanId) public override(ISizeFunctions) {
        ClaimParams memory params = ClaimParams({loanId: loanId, lender: msg.sender, protocol: address(this)});
        _validateClaim(params);
        _executeClaim(params);
    }

    /// @inheritdoc ISizeFunctions
    function liquidateBorrower(address borrower)
        public
        override(ISizeFunctions)
        returns (uint256 actualAmountETH, uint256 targetAmountETH)
    {
        LiquidateBorrowerParams memory params = LiquidateBorrowerParams({borrower: borrower, liquidator: msg.sender});
        _validateLiquidateBorrower(params);
        (actualAmountETH, targetAmountETH) = _executeLiquidateBorrower(params);
        _validateUserIsNotLiquidatable(params.borrower);
    }

    /// @inheritdoc ISizeFunctions
    function liquidateLoan(uint256 loanId) public override(ISizeFunctions) {
        LiquidateLoanParams memory params = LiquidateLoanParams({loanId: loanId, liquidator: msg.sender});
        _validateLiquidateLoan(params);
        _executeLiquidateLoan(params);
    }
}
