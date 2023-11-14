// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISize {
    event LiquidationAtLoss(uint256 amount);

    error TODO();
    error PastDueDate();
    error NothingToRepay();
    error InvalidLender();
    error NotLiquidatable();
    error InvalidLoanId(uint256 loanId);
    error InvalidOfferId(uint256 offerId);
    error DueDateOutOfRange(uint256 maxDueDate);
    error InvalidAmount(uint256 maxAmount);
    error NotEnoughCash(uint256 free, uint256 required);
    error NotEnoughCollateral(uint256 free, uint256 required);
}