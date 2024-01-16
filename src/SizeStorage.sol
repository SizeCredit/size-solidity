// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FixedLoan} from "@src/libraries/FixedLoanLibrary.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";
import {ScaledBorrowToken} from "@src/token/ScaledBorrowToken.sol";
import {ScaledDebtToken} from "@src/token/ScaledDebtToken.sol";

// NOTE changing any of these structs' order will change the storage layout
struct General {
    IPriceFeed priceFeed;
    IERC20Metadata collateralAsset;
    IERC20Metadata borrowAsset;
    address variablePool;
    address insurance;
    address feeRecipient;
}

struct Fixed {
    mapping(address => User) users;
    FixedLoan[] loans;
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
    uint256 liquidityIndexBorrowRAY;
    uint256 liquidityIndexSupplyRAY;
    uint256 lastUpdate;
    CollateralToken collateralToken;
    ScaledBorrowToken scaledBorrowToken;
    ScaledDebtToken scaledDebtToken;
}

struct State {
    General _general;
    Fixed _fixed;
    Variable _variable;
}

abstract contract SizeStorage {
    State internal state;
}
