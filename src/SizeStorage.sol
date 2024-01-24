// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

// NOTE changing any of these structs' order or variables may change the storage layout
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

struct State {
    General _general;
    Fixed _fixed;
}

abstract contract SizeStorage {
    State internal state;
}
