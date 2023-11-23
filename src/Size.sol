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
import {SizeExit, ExitParams} from "@src/SizeExit.sol";

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
    SizeBorrowAsMarketOrder,
    SizeBorrowAsLimitOrder,
    SizeLendAsLimitOrder,
    SizeExit,
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
        if (cash == 0 && eth == 0) {
            revert ERROR_NULL_AMOUNT();
        }

        users[msg.sender].cash.free += cash;
        users[msg.sender].eth.free += eth;
    }

    function withdraw(uint256 cash, uint256 eth) public {
        if (cash == 0 && eth == 0) {
            revert ERROR_NULL_AMOUNT();
        }

        users[msg.sender].cash.free -= cash;
        users[msg.sender].eth.free -= eth;

        _validateUserIsNotLiquidatable(msg.sender);
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
        _lendAsLimitOrder(params);
    }

    function borrowAsLimitOrder(uint256 maxAmount, uint256[] calldata timeBuckets, uint256[] calldata rates) public {
        BorrowAsLimitOrderParams memory params = BorrowAsLimitOrderParams({
            borrower: msg.sender,
            maxAmount: maxAmount,
            curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
        });
        _validateBorrowAsLimitOrder(params);
        _borrowAsLimitOrder(params);
    }

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount) public {
        address lender = msg.sender;
        BorrowOffer storage borrowOffer = users[borrower].borrowOffer;
        User storage lenderUser = users[lender];

        if (amount > borrowOffer.maxAmount) {
            revert ERROR_AMOUNT_GREATER_THAN_MAX_AMOUNT(amount, borrowOffer.maxAmount);
        }
        if (lenderUser.cash.free < amount) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(lenderUser.cash.free, amount);
        }

        // uint256 rate = offer.getRate(dueDate);
        // uint256 r = (PERCENT + rate);

        (dueDate);

        emit TODO();
        revert();
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
        params.amount = _borrowWithVirtualCollateral(params);
        _borrowWithRealCollateral(params);

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
        returns (uint256)
    {
        // NOTE: The exit is equivalent to a spot swap for exact amount in wheres
        // - the exiting lender is the taker
        // - the other lenders are the makers
        // The swap traverses the `loanOfferIds` as they if they were ticks with liquidity in an orderbook
        ExitParams memory params = ExitParams({
            exiter: msg.sender,
            loanId: loanId,
            amount: amount,
            dueDate: dueDate,
            lendersToExitTo: lendersToExitTo
        });

        _validateExit(params);
        return _exit(params);
    }

    // decreases borrower free cash
    // increases protocol free cash
    // increases lender claim(???)

    // decreases borrower locked eth??
    // decreases borrower totDebtCoveredByRealCollateral

    // sets loan to repaid
    function repay(uint256 loanId, uint256 amount) public {
        Loan storage loan = loans[loanId];
        User storage borrower = users[loan.borrower];
        User storage protocol = users[address(this)];
        if (!loan.isFOL()) {
            revert ERROR_ONLY_FOL_CAN_BE_REPAID(loanId);
        }
        if (loan.repaid) {
            revert ERROR_LOAN_ALREADY_REPAID(loanId);
        }
        if (amount < loan.FV) {
            revert ERROR_INVALID_PARTIAL_REPAY_AMOUNT(amount, loan.FV);
        }
        if (borrower.cash.free < amount) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(borrower.cash.free, amount);
        }

        borrower.cash.transfer(protocol.cash, amount);
        borrower.totDebtCoveredByRealCollateral -= loan.FV;
        loan.repaid = true;
    }

    function claim(uint256 loanId) public {
        Loan storage loan = loans[loanId];
        User storage protocolUser = users[address(this)];
        User storage lenderUser = users[loan.lender];

        if (!loan.isRepaid(loans)) {
            revert ERROR_LOAN_NOT_REPAID(loanId);
        }
        if (loan.claimed) {
            revert ERROR_LOAN_ALREADY_CLAIMED(loanId);
        }
        if (loan.lender != msg.sender) {
            revert ERROR_CLAIMER_IS_NOT_LENDER(msg.sender, loan.lender);
        }

        protocolUser.cash.transfer(lenderUser.cash, loan.FV);
    }

    function _liquidationSwap(User storage liquidator, User storage borrower, uint256 amountUSDC, uint256 amountETH)
        private
    {
        liquidator.cash.transfer(borrower.cash, amountUSDC);
        borrower.cash.lock(amountUSDC);
        borrower.eth.unlock(amountETH);
        borrower.eth.transfer(liquidator.eth, amountETH);
    }

    function liquidateBorrower(address _borrower) public returns (uint256, uint256) {
        User storage borrower = users[_borrower];
        User storage liquidator = users[msg.sender];

        if (!isLiquidatable(_borrower)) {
            revert ERROR_NOT_LIQUIDATABLE(_borrower);
        }
        // @audit partial liquidations? maybe not, just assume flash loan??
        if (liquidator.cash.free < borrower.totDebtCoveredByRealCollateral) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(liquidator.cash.free, borrower.totDebtCoveredByRealCollateral);
        }

        uint256 temp = borrower.cash.locked;

        (temp);

        uint256 amountUSDC = borrower.totDebtCoveredByRealCollateral - borrower.cash.locked;

        uint256 targetAmountETH = (amountUSDC * 1e18) / priceFeed.getPrice();
        uint256 actualAmountETH = Math.min(targetAmountETH, borrower.eth.locked);
        if (actualAmountETH < targetAmountETH) {
            // @audit why would this happen? should we prevent the liquidator from doing it?
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        _liquidationSwap(liquidator, borrower, amountUSDC, actualAmountETH);

        borrower.totDebtCoveredByRealCollateral = 0;

        return (actualAmountETH, targetAmountETH);
    }

    function liquidateLoan(uint256 loanId) public {
        (loanId);
        emit TODO();
        revert();
    }
}
