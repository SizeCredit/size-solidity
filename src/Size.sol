// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {SizeValidations} from "./SizeValidations.sol";
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

contract Size is
    ISize,
    SizeValidations,
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
        IPriceFeed _priceFeed,
        uint256 _CROpening,
        uint256 _CRLiquidation,
        uint256 _collateralPercPremiumToLiquidator,
        uint256 _collateralPercPremiumToBorrower
    ) public initializer {
        __Ownable_init(_owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        _validateNonNull(_owner);
        _validateNonNull(address(_priceFeed));
        _validateCollateralRatio(_CROpening);
        _validateCollateralRatio(_CRLiquidation);
        _validateCollateralRatio(_CROpening, _CRLiquidation);
        _validateCollateralPercentagePremium(_collateralPercPremiumToLiquidator);
        _validateCollateralPercentagePremium(_collateralPercPremiumToBorrower);
        _validateCollateralPercentagePremium(_collateralPercPremiumToLiquidator, _collateralPercPremiumToBorrower);

        priceFeed = _priceFeed;
        CROpening = _CROpening;
        CRLiquidation = _CRLiquidation;
        collateralPercPremiumToLiquidator = _collateralPercPremiumToLiquidator;
        collateralPercPremiumToBorrower = _collateralPercPremiumToBorrower;

        // NOTE Necessary so that loanIds start at 1, and 0 is reserved for SOLs
        Loan memory l;
        loans.push(l);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function deposit(uint256 cash, uint256 eth) public {
        DepositParams memory params = DepositParams({user: msg.sender, cash: cash, eth: eth});
        _validateDeposit(params);
        _executeDeposit(params);
    }

    function withdraw(uint256 cash, uint256 eth) public {
        WithdrawParams memory params = WithdrawParams({user: msg.sender, cash: cash, eth: eth});
        _validateWithdraw(params);
        _executeWithdraw(params);
        _validateUserIsNotLiquidatable(params.user);
    }

    function lendAsLimitOrder(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256[] calldata timeBuckets,
        uint256[] calldata rates
    ) public {
        LendAsLimitOrderParams memory params = LendAsLimitOrderParams({
            lender: msg.sender,
            maxAmount: maxAmount,
            maxDueDate: maxDueDate,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        _validateLendAsLimitOrder(params);
        _executeLendAsLimitOrder(params);
    }

    function borrowAsLimitOrder(uint256 maxAmount, uint256[] calldata timeBuckets, uint256[] calldata rates) public {
        BorrowAsLimitOrderParams memory params = BorrowAsLimitOrderParams({
            borrower: msg.sender,
            maxAmount: maxAmount,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        _validateBorrowAsLimitOrder(params);
        _executeBorrowAsLimitOrder(params);
    }

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount) public {
        LendAsMarketOrderParams memory params =
            LendAsMarketOrderParams({lender: msg.sender, borrower: borrower, dueDate: dueDate, amount: amount});
        _validateLendAsMarketOrder(params);
        _executeLendAsMarketOrder(params);
    }

    // decreases lender free cash
    // increases borrower free cash

    // if FOL
    //  increases borrower locked eth
    //  increases borrower totDebtCoveredByRealCollateral

    // decreases loan offer max amount

    // creates new loans
    function borrowAsMarketOrder(
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoansIds
    ) public {
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

    // decreases loanOffer lender free cash
    // increases msg.sender free cash
    // maintains loan borrower accounting

    // decreases loanOffers max amount
    // increases loan amountFVExited

    // creates a new SOL
    function exit(uint256 loanId, uint256 amount, uint256 dueDate, address[] memory lendersToExitTo)
        public
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

    // decreases borrower free cash
    // increases protocol free cash
    // increases lender claim(???)

    // decreases borrower locked eth??
    // decreases borrower totDebtCoveredByRealCollateral

    // sets loan to repaid
    function repay(uint256 loanId, uint256 amount) public {
        RepayParams memory params = RepayParams({loanId: loanId, amount: amount});
        _validateRepay(params);
        _executeRepay(params);
    }

    function claim(uint256 loanId) public {
        ClaimParams memory params = ClaimParams({loanId: loanId, lender: msg.sender, protocol: address(this)});
        _validateClaim(params);
        _executeClaim(params);
    }

    function liquidateBorrower(address borrower) public returns (uint256 actualAmountETH, uint256 targetAmountETH) {
        LiquidateBorrowerParams memory params = LiquidateBorrowerParams({borrower: borrower, liquidator: msg.sender});
        _validateLiquidateBorrower(params);
        (actualAmountETH, targetAmountETH) = _executeLiquidateBorrower(params);
        _validateUserIsNotLiquidatable(params.borrower);
    }

    function liquidateLoan(uint256 loanId) public {
        LiquidateLoanParams memory params = LiquidateLoanParams({loanId: loanId, liquidator: msg.sender});
        _validateLiquidateLoan(params);
        _executeLiquidateLoan(params);
    }
}
