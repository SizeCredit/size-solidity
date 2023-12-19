// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Loan} from "@src/libraries/LoanLibrary.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowerExitParams {
    uint256 loanId;
    uint256 amount;
    uint256 dueDate;
    address[] borrowersToExitTo;
}

library BorrowerExit {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function validateBorrowerExit(State storage state, BorrowerExitParams calldata params) external view {}

    function executeBorrowerExit(State storage state, BorrowerExitParams calldata params)
        external
        returns (uint256 amountInLeft)
    {}
}
