// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./libraries/OfferLibrary.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/ScheduleLibrary.sol";
import "./libraries/RealCollateralLibrary.sol";
import "./libraries/MathLibrary.sol";
import "./libraries/LoanLibrary.sol";

contract Orderbook is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable {
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
    error Orderbook__DueDateOutOfRange(uint256 maxDueDate);
    error Orderbook__InvalidAmount(uint256 maxAmount);
    error Orderbook__NotEnoughCash(uint256 free, uint256 required);

    Offer[] public offers;
    FOL[] public activeFOLs;
    SOL[] public activeSOLs;
    mapping(address => User) public users;
    uint256 public price;
    uint256 public CROpening;
    uint256 public CRLiquidation;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        Offer memory emptyOffer;
        offers.push(emptyOffer);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function place(Offer memory offer) public {
        offers.push(offer);
    }

    function pick(uint256 offerId, uint256 amount, uint256 dueDate) public {
        Offer storage offer = offers[offerId];

        if (dueDate <= block.timestamp) revert Orderbook__PastDueDate();
        if (dueDate > offer.maxDueDate)
            revert Orderbook__DueDateOutOfRange(offer.maxDueDate);
        if (amount > offer.maxAmount)
            revert Orderbook__InvalidAmount(offer.maxAmount);
        if (offer.lender.cash.free < amount)
            revert Orderbook__NotEnoughCash(offer.lender.cash.free, amount);

        uint256 FV = ((PERCENT + offer.getFinalRate(dueDate)) * amount) /
            PERCENT;

        User storage borrower = users[msg.sender];
        borrower.schedule.dueFV[dueDate] += FV;
        int256[] memory RANC = borrower.schedule.RANC(borrower.cash.locked);
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

        if (gteZero) {
            offer.lender.schedule.expectedFV[dueDate] += FV;

            if (amount == offer.maxAmount) {
                delete offers[offerId];
            } else {
                offers[offerId].maxAmount -= amount;
            }
        } else {
            uint256 maxUserDebtUncovered = uint256(-min);
            borrower.totDebtCoveredByRealCollateral = maxUserDebtUncovered;
            uint256 maxETHToLock = (borrower.totDebtCoveredByRealCollateral *
                CROpening) / price;
            if (!borrower.eth.lock(maxETHToLock)) {
                borrower.schedule.dueFV[dueDate] -= FV;
                require(false, "not enough collateral");
            }
            offer.lender.cash.transfer(borrower.cash, amount);
            FOL memory fol = FOL({
                loan: Loan({FV: FV, amountFVExited: 0}),
                lender: offer.lender,
                borrower: borrower,
                dueDate: dueDate,
                FVCoveredByRealCollateral: maxUsdcToLock
            });
            activeFOLs.push(fol);
        }
    }

    function getBorrowerStatus(
        address _borrower
    ) public view returns (BorrowerStatus memory) {
        User storage borrower = users[_borrower];
        uint256 lockedStart = borrower.cash.locked +
            borrower.eth.locked *
            price;
        return
            BorrowerStatus({
                expectedFV: borrower.schedule.expectedFV,
                unlocked: borrower.schedule.unlocked,
                dueFV: borrower.schedule.dueFV,
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
        Loan storage loan = isFOL
            ? activeFOLs[loanId].loan
            : activeSOLs[loanId].loan;
        address loanLender = isFOL
            ? activeFOLs[loanId].lender.account
            : activeSOLs[loanId].lender.account;
        if (loanLender != lender) revert Orderbook__InvalidLender();
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
        FOL storage fol = activeFOLs[loanId];
        if (fol.FVCoveredByRealCollateral == 0)
            revert Orderbook__NothingToRepay();
        if (fol.borrower.cash.free < amount)
            revert Orderbook__NotEnoughCash(fol.borrower.cash.free, amount);
        if (amount < fol.FVCoveredByRealCollateral)
            revert Orderbook__InvalidAmount(fol.FVCoveredByRealCollateral);

        uint256 excess = amount - fol.FVCoveredByRealCollateral;

        fol.borrower.cash.free -= amount;
        fol.lender.cash.locked += fol.FVCoveredByRealCollateral;
        fol.borrower.totDebtCoveredByRealCollateral -= fol
            .FVCoveredByRealCollateral;
        fol.FVCoveredByRealCollateral = 0;
    }

    function unlock(uint256 loanId, uint256 time, uint256 amount) public {
        FOL storage loan = activeFOLs[loanId];
        loan.lender.schedule.unlocked[time] += amount;
        uint256 length = loan.lender.schedule.length();

        int256[] memory RANC = loan.lender.schedule.RANC();
        bool gteZero = true;
        for (uint256 i = 0; i < RANC.length; i++) {
            if (RANC[i] < 0) {
                gteZero = false;
            }
        }
        if (!gteZero) {
            loan.lender.schedule.unlocked[time] -= amount;
            require(false, "impossible to unlock loan");
        }
    }

    function _computeCollateralForDebt(
        uint256 amountUSDC
    ) private returns (uint256) {
        return amountUSDC / price;
    }

    function _liquidationSwap(
        User storage liquidator,
        User storage borrower,
        uint256 amountUSDC,
        uint256 amountETH
    ) private returns (uint256) {
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

        if (!borrower.isLiquidatable(price, CRLiquidation)) revert Orderbook__NotLiquidatable();
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

        FOL storage fol = activeFOLs[loanId];
        int256[] memory RANC = fol.borrower.schedule.RANC();

        if (RANC[fol.dueDate] >= 0) revert Orderbook__NotLiquidatable();

        uint256 loanDebtUncovered = uint256(-1 * RANC[fol.dueDate]);
        uint256 totBorroweDebt = fol.borrower.totDebtCoveredByRealCollateral;
        uint256 loanCollateral = (fol.borrower.eth.locked * loanDebtUncovered) /
            totBorroweDebt;

        if (!fol.borrower.isLiquidatable(price, CRLiquidation)) revert Orderbook__NotLiquidatable();
        if (liquidator.cash.free < loanDebtUncovered)
            revert Orderbook__NotEnoughCash(
                liquidator.cash.free,
                loanDebtUncovered
            );

        uint256 targetAmountETH = _computeCollateralForDebt(loanDebtUncovered);
        uint256 actualAmountETH = Math.min(
            targetAmountETH,
            fol.borrower.eth.locked
        );
        if (actualAmountETH < targetAmountETH) {
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        _liquidationSwap(
            liquidator,
            fol.borrower,
            loanDebtUncovered,
            loanCollateral
        );
    }
}
