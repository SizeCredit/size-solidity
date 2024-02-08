// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {UserView} from "@src/SizeView.sol";
import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";

import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";
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
        uint256 variablePoolBorrowAmount;
        uint256 totalDebtAmount;
    }

    address internal sender;
    Vars internal _before;
    Vars internal _after;

    modifier getSender() virtual {
        sender = msg.sender;
        _;
    }

    function __snapshot(Vars storage vars, uint256 loanId) internal {
        Loan memory l;
        UserView memory e;
        Loan memory loan = loanId == RESERVED_ID ? l : size.getLoan(loanId);
        vars.sender = size.getUserView(sender);
        vars.borrower = loanId == RESERVED_ID ? e : size.getUserView(loan.generic.borrower);
        vars.lender = loanId == RESERVED_ID ? e : size.getUserView(loan.generic.lender);
        vars.isSenderLiquidatable = size.isUserLiquidatable(sender);
        vars.isBorrowerLiquidatable = loanId == RESERVED_ID ? false : size.isUserLiquidatable(loan.generic.borrower);
        vars.senderCollateralAmount = weth.balanceOf(sender);
        vars.senderBorrowAmount = usdc.balanceOf(sender);
        vars.activeLoans = size.activeLoans();
        vars.variablePoolBorrowAmount = size.getUserView(address(variablePool)).borrowAmount;
        (,, NonTransferrableToken debtToken) = size.tokens();
        vars.totalDebtAmount = debtToken.totalSupply();
    }

    function __before(uint256 loanId) internal {
        __snapshot(_before, loanId);
    }

    function __after(uint256 loanId) internal {
        __snapshot(_after, loanId);
    }

    function __before() internal {
        return __before(RESERVED_ID);
    }

    function __after() internal {
        return __after(RESERVED_ID);
    }
}
