// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/console.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function addCash(uint256 amount) public {
        users[msg.sender].cash.free += amount;
    }

    function place(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256 ratePerTimeUnit
    ) public {
        offers[++offerIdCounter] = Offer({
            lender: msg.sender,
            maxAmount: maxAmount,
            maxDueDate: maxDueDate,
            ratePerTimeUnit: ratePerTimeUnit
        });
    }

    function pick(uint256 offerId, uint256 amount, uint256 dueDate) public {
        if (offerId == 0 || offerId > offerIdCounter) {
            revert Orderbook__InvalidOfferId(offerId);
        }

        Offer storage offer = offers[offerId];

        if (dueDate <= block.timestamp) revert Orderbook__PastDueDate();
        if (dueDate > offer.maxDueDate)
            revert Orderbook__DueDateOutOfRange(offer.maxDueDate);
        if (amount > offer.maxAmount)
            revert Orderbook__InvalidAmount(offer.maxAmount);
        if (users[offer.lender].cash.free < amount)
            revert Orderbook__NotEnoughCash(
                users[offer.lender].cash.free,
                amount
            );

        uint256 FV = ((PERCENT + offer.getFinalRate(dueDate)) * amount) /
            PERCENT;

        User storage borrower = users[msg.sender];
        borrower.schedule.dueFV.increment(dueDate, FV);
        int256[] memory RANC = borrower.schedule.RANC(borrower.cash.locked);
        console.log("RANC", RANC.length);
        uint256 maxUsdcToLock = 0;

        int256 min = type(int256).max;
        bool gteZero = true;
        for (uint256 i = 0; i < RANC.length; i++) {
            if (RANC[i] < min) {
                min = RANC[i];
            }
            if (RANC[i] < 0) {
                gteZero = false;
            }
        }

        if (!gteZero) {
            uint256 maxUserDebtUncovered = uint256(-min);
            borrower.totDebtCoveredByRealCollateral = maxUserDebtUncovered;
            uint256 maxETHToLock = (borrower.totDebtCoveredByRealCollateral *
                CROpening) / priceFeed.getPrice();
            if (!borrower.eth.lock(maxETHToLock)) {
                borrower.schedule.dueFV.decrement(dueDate, FV);
                // TX Reverts
                require(false, "not enough collateral");
            }
            users[offer.lender].cash.transfer(borrower.cash, amount);
            Loan memory loan = Loan({
                FV: FV,
                amountFVExited: 0,
                lender: offer.lender,
                borrower: borrower.account,
                dueDate: dueDate,
                FVCoveredByRealCollateral: maxUsdcToLock,
                repaid: false,
                folId: 0
            });
            loans.push(loan);
        }

        if (amount == offer.maxAmount) {
            delete offers[offerId];
        } else {
            offers[offerId].maxAmount -= amount;
        }

        users[offer.lender].schedule.expectedFV.increment(dueDate, FV);
        users[offer.lender].cash.transfer(borrower.cash, amount);

        // createFOL
        // activeLoans[self.uidLoans] = FOL(context=self.context, lender=lender, borrower=borrower, FV=FV, DueDate=dueDate, FVCoveredByRealCollateral=FVCoveredByRealCollateral, amountFVExited=0)
        // self.uidLoans += 1
        // return self.uidLoans-1
    }

    function getBorrowerStatus(
        address _borrower
    ) public returns (BorrowerStatus memory) {
        User storage borrower = users[_borrower];
        uint256 lockedStart = borrower.cash.locked +
            borrower.eth.locked *
            priceFeed.getPrice();
        return
            BorrowerStatus({
                expectedFV: borrower.schedule.expectedFV.values(),
                unlocked: borrower.schedule.unlocked.values(),
                dueFV: borrower.schedule.dueFV.values(),
                RANC: borrower.schedule.RANC(lockedStart)
            });
    }

    function exit(
        address lender,
        bool isFOL,
        uint256 loanId,
        uint256 amount,
        uint256[] memory offersIds
    ) public {
        Loan storage loan = loans[loanId];
        if (loan.getLender(loans) != lender) revert Orderbook__InvalidLender();
        if (amount > loan.maxExit())
            revert Orderbook__InvalidAmount(loan.maxExit());

        uint256 amountLeft = amount;
        uint256 length = offersIds.length;
        for (uint256 i = 0; i < length; ++i) {
            Offer storage offer = offers[offersIds[i]];
        }
        revert("not implemented");
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

        int256[] memory RANC = users[loan.lender].schedule.RANC();
        bool gteZero = true;
        for (uint256 i = 0; i < RANC.length; i++) {
            if (RANC[i] < 0) {
                gteZero = false;
            }
        }
        if (!gteZero) {
            users[loan.lender].schedule.unlocked.decrement(time, amount);
            require(false, "impossible to unlock loan");
        }
    }

    function _computeCollateralForDebt(
        uint256 amountUSDC
    ) private returns (uint256) {
        return amountUSDC / priceFeed.getPrice();
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
        address _liquidator = msg.sender;
        User storage borrower = users[_borrower];
        User storage liquidator = users[_liquidator];

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

    function liquidate(uint256 loanId) public {
        address _liquidator = msg.sender;
        User storage liquidator = users[_liquidator];

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
