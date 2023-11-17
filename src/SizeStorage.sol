// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./oracle/IPriceFeed.sol";
import "./libraries/LoanLibrary.sol";
import "./libraries/OfferLibrary.sol";

abstract contract SizeStorage {
    LoanOffer[] public loanOffers;
    BorrowOffer[] public borrowOffers;
    Loan[] public loans;
    mapping(address => User) internal users;
    IPriceFeed public priceFeed;
    uint256 public maxTime;
    uint256 public CROpening;
    uint256 public CRLiquidation;
    uint256 public collateralPercPremiumToLiquidator;
    uint256 public collateralPercPremiumToBorrower;
}
