// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {UserView} from "@src/libraries/UserLibrary.sol";
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
        uint256 activeLoans;
        uint256 protocolBorrowAmount;
    }

    address internal sender;
    Vars internal _before;
    Vars internal _after;

    modifier getSender() virtual {
        sender = msg.sender;
        _;
    }

    function __before(uint256 loanId) internal {
        Loan memory l;
        UserView memory e;
        Loan memory loan = loanId == RESERVED_ID ? l : size.getLoan(loanId);
        _before.sender = size.getUserView(sender);
        _before.borrower = loanId == RESERVED_ID ? e : size.getUserView(loan.borrower);
        _before.lender = loanId == RESERVED_ID ? e : size.getUserView(loan.lender);
        _before.isSenderLiquidatable = size.isLiquidatable(sender);
        _before.isBorrowerLiquidatable = loanId == RESERVED_ID ? false : size.isLiquidatable(loan.borrower);
        _before.senderCollateralAmount = weth.balanceOf(sender);
        _before.senderBorrowAmount = usdc.balanceOf(sender);
        _before.activeLoans = size.activeLoans();
        (, _before.protocolBorrowAmount,) = size.getVariablePool();
    }

    function __after(uint256 loanId) internal {
        Loan memory l;
        UserView memory e;
        Loan memory loan = loanId == RESERVED_ID ? l : size.getLoan(loanId);
        _after.sender = size.getUserView(sender);
        _after.borrower = loanId == RESERVED_ID ? e : size.getUserView(loan.borrower);
        _after.lender = loanId == RESERVED_ID ? e : size.getUserView(loan.lender);
        _after.isSenderLiquidatable = size.isLiquidatable(sender);
        _after.isBorrowerLiquidatable = loanId == RESERVED_ID ? false : size.isLiquidatable(loan.borrower);
        _after.senderCollateralAmount = weth.balanceOf(sender);
        _after.senderBorrowAmount = usdc.balanceOf(sender);
        _after.activeLoans = size.activeLoans();
        (, _after.protocolBorrowAmount,) = size.getVariablePool();
    }

    function __before() internal {
        return __before(RESERVED_ID);
    }

    function __after() internal {
        return __after(RESERVED_ID);
    }
}
