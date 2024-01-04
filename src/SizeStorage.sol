// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Loan, VariableLoan} from "@src/libraries/LoanLibrary.sol";

import {User} from "@src/libraries/UserLibrary.sol";
import {VariablePoolConfig, VariablePoolState} from "@src/libraries/actions/VariablePool.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

struct Tokens {
    IERC20Metadata collateralAsset;
    IERC20Metadata borrowAsset;
    CollateralToken collateralToken;
    BorrowToken borrowToken;
    DebtToken debtToken;
}

struct Config {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToProtocol;
    uint256 minimumCredit;
    IPriceFeed priceFeed;
    address variablePool;
    address insurance;
    address feeRecipient;
}

// NOTE: changing any of these structs will change the storage layout
struct State {
    // slot 0
    mapping(address => User) users;
    // slot 1
    Loan[] loans;
    // slot 2
    VariableLoan[] variableLoans;
    // slot
    Tokens tokens;
    Config config;
}
// WIP
// VariablePoolConfig variablePoolConfig;
// VariablePoolState variablePoolState;

abstract contract SizeStorage {
    State public state;
}
