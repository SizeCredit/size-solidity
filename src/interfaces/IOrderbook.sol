// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IOrderbook {
    event LiquidationAtLoss(uint256 amount);

    error TODO();
    error Orderbook__PastDueDate();
    error Orderbook__NothingToRepay();
    error Orderbook__InvalidLender();
    error Orderbook__NotLiquidatable();
    error Orderbook__InvalidLoanId(uint256 loanId);
    error Orderbook__InvalidOfferId(uint256 offerId);
    error Orderbook__DueDateOutOfRange(uint256 maxDueDate);
    error Orderbook__InvalidAmount(uint256 maxAmount);
    error Orderbook__NotEnoughCash(uint256 free, uint256 required);
    error Orderbook__NotEnoughCollateral(uint256 free, uint256 required);
}