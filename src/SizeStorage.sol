// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";

struct State {
    mapping(address => User) users;
    Loan[] loans;
    IPriceFeed priceFeed;
    IERC20 collateralAsset;
    IERC20 borrowAsset;
    uint256 maxTime;
    uint256 CROpening;
    uint256 CRLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
    uint256 liquidationProfitETH;
}

abstract contract SizeStorage {
    State public state;
}
