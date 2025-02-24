// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title Events
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library Events {
    // actions

    event Initialize(address indexed sender);
    event Deposit(
        address indexed sender, address indexed onBehalfOf, address indexed token, address to, uint256 amount
    );
    event Withdraw(
        address indexed sender, address indexed onBehalfOf, address indexed token, address to, uint256 amount
    );
    event UpdateConfig(address indexed sender, string indexed key, uint256 value);
    event VariablePoolBorrowRateUpdated(address indexed sender, uint128 oldBorrowRate, uint128 newBorrowRate);
    event SellCreditMarket( /* onBehalfOf */
        address indexed sender,
        address indexed borrower,
        address indexed lender,
        address recipient,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        uint256 deadline,
        uint256 maxAPR,
        bool exactAmountIn
    );
    event SellCreditLimit(
        address indexed sender,
        address indexed onBehalfOf,
        uint256 maxDueDate,
        uint256[] curveRelativeTimeTenors,
        int256[] curveRelativeTimeAprs,
        uint256[] curveRelativeTimeMarketRateMultipliers
    );
    event BuyCreditMarket( /* onBehalfOf */
        address indexed sender,
        address indexed lender,
        address indexed borrower,
        address recipient,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        uint256 deadline,
        uint256 minAPR,
        bool exactAmountIn
    );
    event BuyCreditLimit(
        address indexed sender,
        address indexed onBehalfOf,
        uint256 maxDueDate,
        uint256[] curveRelativeTimeTenors,
        int256[] curveRelativeTimeAprs,
        uint256[] curveRelativeTimeMarketRateMultipliers
    );
    event Repay(address indexed sender, uint256 indexed debtPositionId, address indexed borrower);
    event Claim(address indexed sender, uint256 indexed creditPositionId);
    event Liquidate(
        address indexed sender,
        uint256 indexed debtPositionId,
        uint256 minimumCollateralProfit,
        uint256 deadline,
        uint256 collateralRatio,
        uint8 loanStatus
    );
    event SelfLiquidate(
        address indexed sender, address indexed borrower, uint256 indexed creditPositionId, address recipient
    );
    event LiquidateWithReplacement(
        address indexed sender,
        uint256 indexed debtPositionId,
        address indexed borrower,
        uint256 minimumCollateralProfit,
        uint256 deadline,
        uint256 minAPR
    );
    event Compensate(
        address indexed sender,
        address indexed onBehalfOf,
        uint256 indexed creditPositionWithDebtToRepayId,
        uint256 creditPositionToCompensateId,
        uint256 amount
    );
    event SetUserConfiguration(
        address indexed sender,
        address indexed onBehalfOf,
        uint256 openingLimitBorrowCR,
        bool allCreditPositionsForSaleDisabled,
        bool creditPositionIdsForSale,
        uint256[] creditPositionIds
    );
    event CopyLimitOrders(
        address indexed sender,
        address indexed onBehalfOf,
        address indexed copyAddress,
        uint256 minTenorLoanOffer,
        uint256 maxTenorLoanOffer,
        uint256 minAPRLoanOffer,
        uint256 maxAPRLoanOffer,
        int256 offsetAPRLoanOffer,
        uint256 minTenorBorrowOffer,
        uint256 maxTenorBorrowOffer,
        uint256 minAPRBorrowOffer,
        uint256 maxAPRBorrowOffer,
        int256 offsetAPRBorrowOffer
    ); // v1.6.1

    // creates

    event CreateDebtPosition(
        uint256 indexed debtPositionId,
        address indexed borrower,
        address indexed lender,
        uint256 futureValue,
        uint256 dueDate
    );
    event CreateCreditPosition(
        uint256 indexed creditPositionId,
        address indexed lender,
        uint256 indexed debtPositionId,
        uint256 exitPositionId,
        uint256 credit,
        bool forSale
    );

    // updates

    event UpdateDebtPosition(
        uint256 indexed debtPositionId, address indexed borrower, uint256 futureValue, uint256 liquidityIndexAtRepayment
    );
    event UpdateCreditPosition(uint256 indexed creditPositionId, address indexed lender, uint256 credit, bool forSale);

    // analytics

    event SwapData(
        uint256 indexed creditPositionId,
        address indexed borrower,
        address indexed lender,
        uint256 credit,
        uint256 cashIn,
        uint256 cashOut,
        uint256 swapFee,
        uint256 fragmentationFee,
        uint256 tenor
    );
}
