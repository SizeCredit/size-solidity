// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISize {
    function deposit(uint256 cash, uint256 eth) external;

    function withdraw(uint256 cash, uint256 eth) external;

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
    ) external;

    function borrowAsLimitOrder(uint256 maxAmount, uint256[] calldata timeBuckets, uint256[] calldata rates) external;

    function lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount) external;

    function lendAsLimitOrder(
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256[] calldata timeBuckets,
        uint256[] calldata rates
    ) external;

    // decreases loanOffer lender free cash
    // increases msg.sender free cash
    // maintains loan borrower accounting
    // decreases loanOffers max amount
    // increases loan amountFVExited
    // creates a new SOL
    function exit(uint256 loanId, uint256 amount, uint256 dueDate, address[] memory lendersToExitTo)
        external
        returns (uint256 amountInLeft);

    // decreases borrower free cash
    // increases protocol free cash
    // increases lender claim(???)
    // decreases borrower locked eth??
    // decreases borrower totDebtCoveredByRealCollateral
    // sets loan to repaid
    function repay(uint256 loanId, uint256 amount) external;

    function claim(uint256 loanId) external;

    function liquidateBorrower(address borrower) external returns (uint256 actualAmountETH, uint256 targetAmountETH);

    function liquidateLoan(uint256 loanId) external;
}
