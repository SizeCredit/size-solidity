// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {UserView} from "@src/SizeView.sol";
import {RESERVED_ID} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {Deploy} from "@test/Deploy.sol";

abstract contract BeforeAfter is Deploy {
    struct Vars {
        UserView sender;
        UserView borrower;
        UserView lender;
        bool isSenderLiquidatable;
        bool isBorrowerLiquidatable;
        uint256 senderCollateralAmount;
        uint256 senderBorrowAmount;
        uint256 activeFixedLoans;
        uint256 variablePoolBorrowAmount;
    }

    address internal sender;
    Vars internal _before;
    Vars internal _after;

    modifier getSender() virtual {
        sender = msg.sender;
        _;
    }

    function __before(uint256 loanId) internal {
        FixedLoan memory l;
        UserView memory e;
        FixedLoan memory loan = loanId == RESERVED_ID ? l : size.getFixedLoan(loanId);
        _before.sender = size.getUserView(sender);
        _before.borrower = loanId == RESERVED_ID ? e : size.getUserView(loan.borrower);
        _before.lender = loanId == RESERVED_ID ? e : size.getUserView(loan.lender);
        _before.isSenderLiquidatable = size.isUserLiquidatable(sender);
        _before.isBorrowerLiquidatable = loanId == RESERVED_ID ? false : size.isUserLiquidatable(loan.borrower);
        _before.senderCollateralAmount = weth.balanceOf(sender);
        _before.senderBorrowAmount = usdc.balanceOf(sender);
        _before.activeFixedLoans = size.activeFixedLoans();
        _before.variablePoolBorrowAmount = size.getUserView(address(variablePool)).borrowAmount;
    }

    function __after(uint256 loanId) internal {
        FixedLoan memory l;
        UserView memory e;
        FixedLoan memory loan = loanId == RESERVED_ID ? l : size.getFixedLoan(loanId);
        _after.sender = size.getUserView(sender);
        _after.borrower = loanId == RESERVED_ID ? e : size.getUserView(loan.borrower);
        _after.lender = loanId == RESERVED_ID ? e : size.getUserView(loan.lender);
        _after.isSenderLiquidatable = size.isUserLiquidatable(sender);
        _after.isBorrowerLiquidatable = loanId == RESERVED_ID ? false : size.isUserLiquidatable(loan.borrower);
        _after.senderCollateralAmount = weth.balanceOf(sender);
        _after.senderBorrowAmount = usdc.balanceOf(sender);
        _after.activeFixedLoans = size.activeFixedLoans();
        _after.variablePoolBorrowAmount = size.getUserView(address(variablePool)).borrowAmount;
    }

    function __before() internal {
        return __before(RESERVED_ID);
    }

    function __after() internal {
        return __after(RESERVED_ID);
    }
}
