// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {console2 as console} from "forge-std/console2.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./OrderbookView.sol";
import "./OrderbookStorage.sol";
import "./libraries/OfferLibrary.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/ScheduleLibrary.sol";
import "./libraries/EnumerableMapExtensionsLibrary.sol";
import "./libraries/RealCollateralLibrary.sol";
import "./libraries/MathLibrary.sol";
import "./libraries/LoanLibrary.sol";
import "./oracle/IPriceFeed.sol";

contract Orderbook is
    OrderbookStorage,
    OrderbookView,
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using EnumerableMapExtensionsLibrary for EnumerableMap.UintToUintMap;
    using OfferLibrary for Offer;
    using ScheduleLibrary for Schedule;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using UserLibrary for User;

    event LiquidationAtLoss(uint256 amount);

    error Orderbook__PastDueDate();
    error Orderbook__NothingToRepay();
    error Orderbook__InvalidLender();
    error Orderbook__NotLiquidatable();
    error Orderbook__InvalidOfferId(uint256 offerId);
    error Orderbook__DueDateOutOfRange(uint256 maxDueDate);
    error Orderbook__InvalidAmount(uint256 maxAmount);
    error Orderbook__NotEnoughCash(uint256 free, uint256 required);

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

        priceFeed = _priceFeed;
        maxTime = _maxTime;
        CROpening = _CROpening;
        CRLiquidation = _CRLiquidation;

        Offer memory o;
        offers.push(o);
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

    function place(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256 ratePerTimeUnit
    ) public {
        offers.push(
            Offer({
                lender: msg.sender,
                maxAmount: maxAmount,
                maxDueDate: maxDueDate,
                ratePerTimeUnit: ratePerTimeUnit
            })
        );
    }

    function pick(uint256 offerId, uint256 amount, uint256 dueDate) public {
        if (offerId == 0 || offerId >= offers.length) {
            revert Orderbook__InvalidOfferId(offerId);
        }

        Offer storage offer = offers[offerId];
        address lender = offer.lender;

        if (dueDate <= block.timestamp) revert Orderbook__PastDueDate();
        if (dueDate > offer.maxDueDate)
            revert Orderbook__DueDateOutOfRange(offer.maxDueDate);
        if (amount > offer.maxAmount)
            revert Orderbook__InvalidAmount(offer.maxAmount);
        if (users[lender].cash.free < amount)
            revert Orderbook__NotEnoughCash(users[lender].cash.free, amount);

        uint256 FV = ((PERCENT + offer.getFinalRate(dueDate)) * amount) /
            PERCENT;

        User storage borrower = users[msg.sender];
        borrower.schedule.dueFV.increment(dueDate, FV);
        uint256 maxUsdcToLock = 0;
        (bool isNegative, int256 min) = borrower.schedule.isNegativeAndMinRANC(
            borrower.cash.locked
        );

        if (isNegative) {
            uint256 maxUserDebtUncovered = uint256(-min);
            borrower.totDebtCoveredByRealCollateral = maxUserDebtUncovered;
            uint256 maxETHToLock = (borrower.totDebtCoveredByRealCollateral *
                CROpening) / priceFeed.getPrice();
            if (!borrower.eth.lock(maxETHToLock)) {
                borrower.schedule.dueFV.decrement(dueDate, FV);
                revert Orderbook__NotEnoughCash(
                    borrower.eth.free,
                    maxETHToLock
                );
            }
        }

        if (amount == offer.maxAmount) {
            delete offers[offerId];
        } else {
            offers[offerId].maxAmount -= amount;
        }

        users[lender].schedule.expectedFV.increment(dueDate, FV);
        users[lender].cash.transfer(borrower.cash, amount);

        loans.push(
            Loan({
                FV: FV,
                amountFVExited: 0,
                lender: offer.lender,
                borrower: msg.sender,
                dueDate: dueDate,
                FVCoveredByRealCollateral: maxUsdcToLock,
                repaid: false,
                folId: 0
            })
        );
    }

    function exit(
        uint256 loanId,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory offersIds
    ) public returns (uint256) {
        // NOTE: The exit is equivalent to a spot swap for exact amount in wheres
        // - the exiting lender is the taker
        // - the other lenders are the makers
        // The swap traverses the `offersIds` as they if they were ticks with liquidity in an orderbook
        Loan storage loan = loans[loanId];
        if (loan.getLender(loans) != msg.sender)
            revert Orderbook__InvalidLender();
        if (amount > loan.maxExit())
            revert Orderbook__InvalidAmount(loan.maxExit());

        uint256 amountInLeft = amount;
        uint256 length = offersIds.length;
        for (uint256 i = 0; i < length; ++i) {
            if (amountInLeft == 0) {
                // No more amountIn to swap
                break;
            }

            Offer storage offer = offers[offersIds[i]];
            uint256 r = PERCENT + offer.getFinalRate(dueDate);
            uint256 deltaAmountIn = Math.min(r * offer.maxAmount, amountInLeft);
            uint256 deltaAmountOut = (deltaAmountIn * PERCENT) / r;

            // Swap
            {
                loans.push(
                    Loan({
                        FV: deltaAmountIn,
                        amountFVExited: 0,
                        lender: offer.lender,
                        borrower: msg.sender,
                        dueDate: loan.dueDate,
                        FVCoveredByRealCollateral: loan
                            .FVCoveredByRealCollateral,
                        repaid: false,
                        folId: loanId
                    })
                );
            }

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
        if (loan.FVCoveredByRealCollateral == 0)
            revert Orderbook__NothingToRepay();
        if (users[loan.borrower].cash.free < amount)
            revert Orderbook__NotEnoughCash(
                users[loan.borrower].cash.free,
                amount
            );
        if (amount < loan.FVCoveredByRealCollateral)
            revert Orderbook__InvalidAmount(loan.FVCoveredByRealCollateral);

        uint256 excess = amount - loan.FVCoveredByRealCollateral;

        users[loan.borrower].cash.free -= amount;
        users[loan.lender].cash.locked += loan.FVCoveredByRealCollateral;
        users[loan.borrower].totDebtCoveredByRealCollateral -= loan
            .FVCoveredByRealCollateral;
        loan.FVCoveredByRealCollateral = 0;
    }

    function unlock(uint256 loanId, uint256 time, uint256 amount) public {
        Loan storage loan = loans[loanId];
        users[loan.lender].schedule.unlocked.increment(time, amount);
        uint256 length = users[loan.lender].schedule.length();

        bool isNegative = users[loan.lender].schedule.isNegativeRANC();
        if (isNegative) {
            users[loan.lender].schedule.unlocked.decrement(time, amount);
            require(false, "impossible to unlock loan");
        }
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

        if (!borrower.isLiquidatable(priceFeed.getPrice(), CRLiquidation))
            revert Orderbook__NotLiquidatable();
        if (liquidator.cash.free < borrower.totDebtCoveredByRealCollateral)
            revert Orderbook__NotEnoughCash(
                liquidator.cash.free,
                borrower.totDebtCoveredByRealCollateral
            );

        uint256 temp = borrower.cash.locked;

        uint256 amountUSDC = borrower.totDebtCoveredByRealCollateral -
            borrower.cash.locked;

        uint256 targetAmountETH = _computeCollateralForDebt(amountUSDC);
        uint256 actualAmountETH = Math.min(
            targetAmountETH,
            borrower.eth.locked
        );
        if (actualAmountETH < targetAmountETH) {
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        _liquidationSwap(liquidator, borrower, amountUSDC, actualAmountETH);

        borrower.totDebtCoveredByRealCollateral = 0;

        return (actualAmountETH, targetAmountETH);
    }

    function liquidateLoan(uint256 loanId) public {
        User storage liquidator = users[msg.sender];

        Loan storage loan = loans[loanId];
        int256[] memory RANC = users[loan.borrower].schedule.RANC();

        if (RANC[loan.dueDate] >= 0) revert Orderbook__NotLiquidatable();

        uint256 loanDebtUncovered = uint256(-1 * RANC[loan.dueDate]);
        uint256 totBorroweDebt = users[loan.borrower]
            .totDebtCoveredByRealCollateral;
        uint256 loanCollateral = (users[loan.borrower].eth.locked *
            loanDebtUncovered) / totBorroweDebt;

        if (
            !users[loan.borrower].isLiquidatable(
                priceFeed.getPrice(),
                CRLiquidation
            )
        ) revert Orderbook__NotLiquidatable();
        if (liquidator.cash.free < loanDebtUncovered)
            revert Orderbook__NotEnoughCash(
                liquidator.cash.free,
                loanDebtUncovered
            );

        uint256 targetAmountETH = _computeCollateralForDebt(loanDebtUncovered);
        uint256 actualAmountETH = Math.min(
            targetAmountETH,
            users[loan.borrower].eth.locked
        );
        if (actualAmountETH < targetAmountETH) {
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        _liquidationSwap(
            liquidator,
            users[loan.borrower],
            loanDebtUncovered,
            loanCollateral
        );
    }
}
