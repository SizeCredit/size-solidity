// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./oracle/IPriceFeed.sol";
import "./libraries/LoanLibrary.sol";
import "./libraries/OfferLibrary.sol";

abstract contract OrderbookStorage {
    mapping(uint256 => Offer) internal offers;
    uint256 internal offerIdCounter;
    Loan[] internal loans;
    mapping(address => User) internal users;
    IPriceFeed public priceFeed;
    uint256 public maxTime;
    uint256 public CROpening;
    uint256 public CRLiquidation;
}