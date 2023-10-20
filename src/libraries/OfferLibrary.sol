// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./UserLibrary.sol";

struct Offer {
    User lender;
    uint256 maxAmount;
    uint256 maxDueDate;
    uint256 ratePerTimeUnit;
}

library OfferLibrary {
    error OfferLibrary__PastDueDate();
    error OfferLibrary__DueDateOutOfRange(uint256 maxDueDate);

    function getFinalRate(
        Offer storage self,
        uint256 dueDate
    ) public view returns (uint256) {
        if (dueDate <= block.timestamp) revert OfferLibrary__PastDueDate();
        if (dueDate > self.maxDueDate)
            revert OfferLibrary__DueDateOutOfRange(self.maxDueDate);

        return self.ratePerTimeUnit * (dueDate - block.timestamp);
    }
}
