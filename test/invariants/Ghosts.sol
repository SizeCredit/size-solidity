// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Asserts} from "@chimera/Asserts.sol";
import {UserView} from "@src/SizeView.sol";
import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {CreditPosition, DebtPosition, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {Deploy} from "@script/Deploy.sol";

abstract contract Ghosts is Deploy, Asserts {
    struct Vars {
        UserView sender;
        UserView borrower;
        UserView lender;
        LoanStatus loanStatus;
        bool isSenderLiquidatable;
        bool isBorrowerLiquidatable;
        uint256 senderCollateralAmount;
        uint256 senderBorrowAmount;
        uint256 debtPositionsCount;
        uint256 creditPositionsCount;
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

    modifier hasLoans() {
        (_before.debtPositionsCount, _before.creditPositionsCount) = size.getPositionsCount();
        precondition(_before.debtPositionsCount > 0);
        _;
    }

    function __snapshot(Vars storage vars, uint256 positionId) internal {
        CreditPosition memory c;
        DebtPosition memory d;
        UserView memory e;
        vars.borrower = e;
        vars.lender = e;
        if (positionId != RESERVED_ID) {
            if (size.isCreditPositionId(positionId)) {
                c = size.getCreditPosition(positionId);
                d = size.getDebtPosition(c.debtPositionId);
                vars.borrower = size.getUserView(d.borrower);
                vars.isBorrowerLiquidatable = size.isUserUnderwater(vars.borrower.account);
                vars.lender = size.getUserView(c.lender);
            } else {
                d = size.getDebtPosition(positionId);
                vars.borrower = size.getUserView(d.borrower);
                vars.isBorrowerLiquidatable = size.isUserUnderwater(d.borrower);
            }
            vars.loanStatus = size.getLoanStatus(positionId);
        }
        vars.sender = size.getUserView(sender);
        vars.isSenderLiquidatable = size.isUserUnderwater(sender);
        vars.senderCollateralAmount = weth.balanceOf(sender);
        vars.senderBorrowAmount = usdc.balanceOf(sender);
        (vars.debtPositionsCount, vars.creditPositionsCount) = size.getPositionsCount();
        vars.variablePoolBorrowAmount = size.getUserView(address(variablePool)).borrowATokenBalance;
        vars.totalDebtAmount = size.data().debtToken.totalSupply();
    }

    function __before(uint256 positionId) internal {
        __snapshot(_before, positionId);
    }

    function __after(uint256 positionId) internal {
        __snapshot(_after, positionId);
    }

    function __before() internal {
        return __before(RESERVED_ID);
    }

    function __after() internal {
        return __after(RESERVED_ID);
    }
}
