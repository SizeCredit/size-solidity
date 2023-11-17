// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {SizeValidations} from "./SizeValidations.sol";

import {YieldCurve} from "./libraries/YieldCurveLibrary.sol";
import {OfferLibrary, LoanOffer, BorrowOffer} from "./libraries/OfferLibrary.sol";
import {UserLibrary, User} from "./libraries/UserLibrary.sol";
import {EnumerableMapExtensionsLibrary} from "./libraries/EnumerableMapExtensionsLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {Math, PERCENT} from "./libraries/MathLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";

import {IPriceFeed} from "./oracle/IPriceFeed.sol";

import {ISize} from "./interfaces/ISize.sol";

contract Size is
    ISize,
    SizeValidations,
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using EnumerableMapExtensionsLibrary for EnumerableMap.UintToUintMap;
    using OfferLibrary for LoanOffer;
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
        uint256 _maxTime,
        uint256 _CROpening,
        uint256 _CRLiquidation
    ) public initializer {
        __Ownable_init(_owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        _validateNonNull(_owner);
        _validateNonNull(address(_priceFeed));
        _validateCollateralRatio(_CROpening);
        _validateCollateralRatio(_CRLiquidation);
        _validateCollateralRatio(_CROpening, _CRLiquidation);

        priceFeed = _priceFeed;
        maxTime = _maxTime;
        CROpening = _CROpening;
        CRLiquidation = _CRLiquidation;

        LoanOffer memory lo;
        loanOffers.push(lo);
        BorrowOffer memory bo;
        borrowOffers.push(bo);
        Loan memory l;
        loans.push(l);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function deposit(uint256 cash, uint256 eth) public {
        users[msg.sender].cash.free += cash;
        users[msg.sender].eth.free += eth;
    }

    function withdraw(uint256 cash, uint256 eth) public {
        users[msg.sender].cash.free -= cash;
        users[msg.sender].eth.free -= eth;

        _validateUserHealthy(msg.sender);
    }

    function lendAsLimitOrder(
        uint256 maxAmount,
        uint256 maxDueDate,
        YieldCurve calldata curveRelativeTime
    ) public {
        loanOffers.push(
            LoanOffer({
                lender: msg.sender,
                maxAmount: maxAmount,
                maxDueDate: maxDueDate,
                curveRelativeTime: curveRelativeTime
            })
        );
    }

    function borrowAsLimitOrder(
        uint256 maxAmount,
        YieldCurve calldata curveRelativeTime
    ) public {
        borrowOffers.push(
            BorrowOffer({
                borrower: msg.sender,
                maxAmount: maxAmount,
                curveRelativeTime: curveRelativeTime
            })
        );
    }

    function lendAsMarketOrder(
        uint256 borrowOfferId,
        uint256 dueDate,
        uint256 amount
    ) public {
        BorrowOffer storage offer = borrowOffers[borrowOfferId];
        User storage lender = users[msg.sender];

        // if (offer.dueDate <= block.timestamp) revert ISize.PastDueDate();
        // if (amount > offer.maxAmount)
        //     revert ISize.InvalidAmount(offer.maxAmount);
        if (lender.cash.free < amount)
            revert ISize.NotEnoughCash(lender.cash.free, amount);

        // uint256 rate = offer.getRate(dueDate);
        // uint256 r = (PERCENT + rate);

        revert TODO();
    }

    function borrowAsMarketOrder(
        uint256 offerId,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoansIds
    ) public {
        User storage borrower = users[msg.sender];
        LoanOffer storage offer = loanOffers[offerId];
        User storage lender = users[offer.lender];
        if(dueDate <= block.timestamp) {
            revert ISize.PastDueDate();
        }
        if (amount > offer.maxAmount) {
            revert ISize.InvalidAmount(offer.maxAmount);
        }
        // if (lender.cash.free < amount) {
        //     revert ISize.NotEnoughCash(lender.cash.free, amount);
        // }

        //  amountIn: Amount of future cashflow to exit
        //  amountOut: Amount of cash to borrow at present time

        uint256 r = PERCENT + offer.getRate(dueDate);

        //  NOTE: The `amountOutLeft` is going to be decreased as more and more SOLs are created

        uint256 amountOutLeft = amount;

        for (uint256 i = 0; i < virtualCollateralLoansIds.length; ++i) {
            uint256 loanId = virtualCollateralLoansIds[i];
            // Full amount borrowed
            if (amountOutLeft == 0) {
                break;
            }

            Loan storage loan = loans[loanId];
            dueDate = dueDate != type(uint256).max
                ? dueDate
                : loan.getDueDate(loans);

            if (loan.lender != msg.sender) {
                revert ISize.InvalidLoanId(loanId);
            }
            if (dueDate > offer.maxDueDate) {
                // loan is due after offer maxDueDate
                continue;
            }
            if (dueDate < loan.getDueDate(loans)) {
                // loan is due before offer dueDate
                continue;
            }

            uint256 amountInLeft = (r * amountOutLeft) / PERCENT;
            uint256 deltaAmountIn;
            uint256 deltaAmountOut;
            if (amountInLeft >= loan.maxExit()) {
                deltaAmountIn = loan.maxExit();
                deltaAmountOut = (loan.maxExit() * PERCENT) / r;
            } else {
                deltaAmountIn = amountInLeft;
                deltaAmountOut = (amountInLeft * PERCENT) / r;
            }

            loans.createSOL(loanId, offer.lender, msg.sender, deltaAmountIn);
            loan.lock(deltaAmountIn);
            // NOTE: Transfer deltaAmountOut for each SOL created
            users[offer.lender].cash.transfer(borrower.cash, deltaAmountOut);
            offer.maxAmount -= deltaAmountOut;
            amountInLeft -= deltaAmountIn;
            amountOutLeft -= deltaAmountOut;
        }

        // TODO cover the remaining amount with real collateral
        if (amountOutLeft > 0) {
            uint256 FV = (r * amountOutLeft) / PERCENT;
            uint256 maxETHToLock = ((FV * CROpening) / priceFeed.getPrice());
            if (!borrower.eth.lock(maxETHToLock)) {
                revert ISize.NotEnoughCash(borrower.eth.free, maxETHToLock);
            }
            // TODO Lock ETH to cover that amount
            borrower.totDebtCoveredByRealCollateral += FV;
            loans.createFOL(offer.lender, msg.sender, FV, dueDate);
            users[offer.lender].cash.transfer(borrower.cash, amountOutLeft);
        }

        _validateUserHealthy(msg.sender);
    }

    function exit(
        uint256 loanId,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory loanOffersIds
    ) public returns (uint256) {
        // NOTE: The exit is equivalent to a spot swap for exact amount in wheres
        // - the exiting lender is the taker
        // - the other lenders are the makers
        // The swap traverses the `loanOffersIds` as they if they were ticks with liquidity in an orderbook
        Loan storage loan = loans[loanId];
        if (loan.lender != msg.sender) revert ISize.InvalidLender();
        if (amount > loan.maxExit()) {
            revert ISize.InvalidAmount(loan.maxExit());
        }

        uint256 amountInLeft = amount;
        uint256 length = loanOffersIds.length;
        for (uint256 i = 0; i < length; ++i) {
            if (amountInLeft == 0) {
                // No more amountIn to swap
                break;
            }

            LoanOffer storage offer = loanOffers[loanOffersIds[i]];
            uint256 r = PERCENT + offer.getRate(dueDate);
            uint256 deltaAmountIn;
            uint256 deltaAmountOut;
            // @audit check rounding direction
            if (amountInLeft >= offer.maxAmount) {
                deltaAmountIn = (r * offer.maxAmount) / PERCENT;
                deltaAmountOut = offer.maxAmount;
            } else {
                deltaAmountIn = amountInLeft;
                deltaAmountOut = (deltaAmountIn * PERCENT) / r;
            }

            loans.createSOL(loanId, offer.lender, msg.sender, deltaAmountIn);
            loan.lock(deltaAmountIn);
            users[offer.lender].cash.transfer(
                users[msg.sender].cash,
                deltaAmountOut
            );
            offer.maxAmount -= deltaAmountOut;
            amountInLeft -= deltaAmountIn;
        }

        return amountInLeft;
    }

    function repay(uint256 loanId, uint256 amount) public {
        Loan storage loan = loans[loanId];
        // if (loan.FVCoveredByRealCollateral == 0) {
        //     revert ISize.NothingToRepay();
        // }
        if (users[loan.borrower].cash.free < amount) {
            revert ISize.NotEnoughCash(users[loan.borrower].cash.free, amount);
        }
        // if (amount < loan.FVCoveredByRealCollateral) {
        //     revert ISize.InvalidAmount(loan.FVCoveredByRealCollateral);
        // }

        // uint256 excess = amount - loan.FVCoveredByRealCollateral;

        // (excess);

        users[loan.borrower].cash.free -= amount;
        // users[loan.lender].cash.locked += loan.FVCoveredByRealCollateral;
        // users[loan.borrower].totDebtCoveredByRealCollateral -= loan
        //     .FVCoveredByRealCollateral;
        // loan.FVCoveredByRealCollateral = 0;
        loan.repaid = true;
    }

    function _computeCollateralForDebt(
        uint256 amountUSDC
    ) private returns (uint256) {
        return (amountUSDC * 1e18) / priceFeed.getPrice();
    }

    function _liquidationSwap(
        User storage liquidator,
        User storage borrower,
        uint256 amountUSDC,
        uint256 amountETH
    ) private {
        liquidator.cash.transfer(borrower.cash, amountUSDC);
        borrower.cash.lock(amountUSDC);
        borrower.eth.unlock(amountETH);
        borrower.eth.transfer(liquidator.eth, amountETH);
    }

    function liquidateBorrower(
        address _borrower
    ) public returns (uint256, uint256) {
        User storage borrower = users[_borrower];
        User storage liquidator = users[msg.sender];

        if (!isLiquidatable(_borrower)) {
            revert ISize.NotLiquidatable();
        }
        // @audit partial liquidations? maybe not, just assume flash loan??
        if (liquidator.cash.free < borrower.totDebtCoveredByRealCollateral) {
            revert ISize.NotEnoughCash(
                liquidator.cash.free,
                borrower.totDebtCoveredByRealCollateral
            );
        }

        uint256 temp = borrower.cash.locked;

        (temp);

        uint256 amountUSDC = borrower.totDebtCoveredByRealCollateral -
            borrower.cash.locked;

        uint256 targetAmountETH = _computeCollateralForDebt(amountUSDC);
        uint256 actualAmountETH = Math.min(
            targetAmountETH,
            borrower.eth.locked
        );
        if (actualAmountETH < targetAmountETH) {
            // @audit why would this happen? should we prevent the liquidator from doing it?
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        _liquidationSwap(liquidator, borrower, amountUSDC, actualAmountETH);

        borrower.totDebtCoveredByRealCollateral = 0;

        return (actualAmountETH, targetAmountETH);
    }

    function liquidateLoan(uint256 loanId) public {
        User storage liquidator = users[msg.sender];

        Loan storage loan = loans[loanId];

        revert TODO();
    }
}
