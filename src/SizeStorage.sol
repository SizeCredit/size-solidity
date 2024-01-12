// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FixedLoan, VariableFixedLoan} from "@src/libraries/FixedLoanLibrary.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";
import {ScaledBorrowToken} from "@src/token/ScaledBorrowToken.sol";

import {ScaledDebtToken} from "@src/token/ScaledDebtToken.sol";
import {ScaledSupplyToken} from "@src/token/ScaledSupplyToken.sol";

struct General {
    IPriceFeed priceFeed;
    IERC20Metadata collateralAsset;
    IERC20Metadata borrowAsset;
    address variablePool;
    address insurance;
    address feeRecipient;
}

struct Fixed {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCredit;
    uint256 collateralPremiumToLiquidator;
    uint256 collateralPremiumToProtocol;
    CollateralToken collateralToken;
    BorrowToken borrowToken;
    DebtToken debtToken;
}

struct Variable {
    uint256 minimumCollateralRatio;
    uint256 minRate;
    uint256 maxRate;
    uint256 slope;
    uint256 optimalUR;
    uint256 reserveFactor;
    uint256 liquidityIndexBorrow;
    uint256 liquidityIndexSupply;
    uint256 capBorrow;
    uint256 capSupply;
    uint256 lastUpdate;
    ScaledSupplyToken scaledSupplyToken;
    ScaledBorrowToken scaledBorrowToken;
    ScaledDebtToken scaledDebtToken;
}

// NOTE: changing any of these structs will change the storage layout
struct State {
    // slot 0
    mapping(address => User) users;
    // slot 1
    FixedLoan[] loans;
    // slot 2
    VariableFixedLoan[] variableFixedLoans;
    // slot ...
    General g;
    Fixed f;
    Variable v;
}

abstract contract SizeStorage {
    State public state;
}
