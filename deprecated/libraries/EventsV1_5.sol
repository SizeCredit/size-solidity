// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LoanStatus} from "@src/market/libraries/LoanLibrary.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

/// @title EventsV1_5
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library EventsV1_5 {
    // actions

    event Initialize(
        InitializeFeeConfigParams f, InitializeRiskConfigParams r, InitializeOracleParams o, InitializeDataParams d
    );
    event ReinitializeV1_5(
        address indexed borrowATokenV1_5,
        uint256 oldTotalSupply,
        uint256 oldScaledTotalSupply,
        uint256 totalSupply,
        uint256 scaledTotalSupply
    );
    event Deposit(address indexed token, address indexed to, uint256 amount);
    event Withdraw(address indexed token, address indexed to, uint256 amount);
    event UpdateConfig(string indexed key, uint256 value);
    event VariablePoolBorrowRateUpdated(uint128 indexed oldBorrowRate, uint128 indexed newBorrowRate);
    event SellCreditMarket(
        address indexed lender,
        uint256 indexed creditPositionId,
        uint256 indexed tenor,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn
    );
    event SellCreditLimit(
        uint256 indexed maxDueDate,
        uint256[] curveRelativeTimeTenors,
        int256[] curveRelativeTimeAprs,
        uint256[] curveRelativeTimeMarketRateMultipliers
    );
    event BuyCreditMarket(
        address indexed borrower,
        uint256 indexed creditPositionId,
        uint256 indexed tenor,
        uint256 amount,
        bool exactAmountIn
    );
    event BuyCreditLimit(
        uint256 indexed maxDueDate,
        uint256[] curveRelativeTimeTenors,
        int256[] curveRelativeTimeAprs,
        uint256[] curveRelativeTimeMarketRateMultipliers
    );
    event Repay(uint256 indexed debtPositionId);
    event Claim(uint256 indexed creditPositionId, uint256 indexed debtPositionId);
    event Liquidate(
        uint256 indexed debtPositionId, uint256 minimumCollateralProfit, uint256 collateralRatio, LoanStatus loanStatus
    );
    event SelfLiquidate(uint256 indexed creditPositionId);
    event LiquidateWithReplacement(
        uint256 indexed debtPositionId, address indexed borrower, uint256 minimumCollateralProfit
    );
    event Compensate(
        uint256 indexed creditPositionWithDebtToRepayId, uint256 indexed creditPositionToCompensateId, uint256 amount
    );
    event SetUserConfiguration(
        uint256 indexed openingLimitBorrowCR,
        bool indexed allCreditPositionsForSaleDisabled,
        bool indexed creditPositionIdsForSale,
        uint256[] creditPositionIds
    );

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
