// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

struct State {
    mapping(address => User) users;
    Loan[] loans;
    IPriceFeed priceFeed;
    IERC20Metadata collateralAsset;
    IERC20Metadata borrowAsset;
    CollateralToken collateralToken;
    BorrowToken borrowToken;
    DebtToken debtToken;
    uint256 maxTime;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
    address protocolVault;
    address feeRecipient;
}

abstract contract SizeStorage {
    State public state;
}
