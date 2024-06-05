// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Asserts} from "@chimera/Asserts.sol";

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {UserView} from "@src/SizeView.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {CreditPosition, DebtPosition, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {Deploy} from "@script/Deploy.sol";

abstract contract Ghosts is Deploy, Asserts, PropertiesConstants {
    struct Vars {
        bytes4 sig;
        uint256 debtPositionId;
        uint256 creditPositionId;
        UserView sender;
        UserView borrower;
        UserView lender;
        UserView feeRecipient;
        LoanStatus loanStatus;
        bool[3] isUserUnderwater;
        bool isSenderUnderwater;
        bool isBorrowerUnderwater;
        uint256 senderCollateralAmount;
        uint256 senderBorrowAmount;
        uint256 borrowerCR;
        uint256 sizeCollateralAmount;
        uint256 sizeBorrowAmount;
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

    modifier clear() {
        Vars memory e;
        _before = e;
        _after = e;
        _;
    }

    function __snapshot(Vars storage vars, uint256 positionId) internal {
        vars.sig = msg.sig;
        vars.debtPositionId = RESERVED_ID;
        vars.creditPositionId = RESERVED_ID;
        (, address feeRecipient) = size.getCryticVariables();
        CreditPosition memory c;
        DebtPosition memory d;
        UserView memory e;
        vars.borrower = e;
        vars.lender = e;
        if (positionId != RESERVED_ID) {
            if (size.isCreditPositionId(positionId)) {
                c = size.getCreditPosition(positionId);
                d = size.getDebtPosition(c.debtPositionId);
                vars.lender = size.getUserView(c.lender);
                vars.debtPositionId = c.debtPositionId;
            } else {
                d = size.getDebtPosition(positionId);
                vars.debtPositionId = positionId;
            }
            vars.borrower = size.getUserView(d.borrower);
            vars.isBorrowerUnderwater = size.isUserUnderwater(d.borrower);
            vars.borrowerCR = size.collateralRatio(d.borrower);
            vars.loanStatus = size.getLoanStatus(positionId);
        }
        vars.sender = size.getUserView(sender);
        vars.feeRecipient = size.getUserView(feeRecipient);
        vars.isSenderUnderwater = size.isUserUnderwater(sender);
        address[3] memory users = [USER1, USER2, USER3];
        for (uint256 i = 0; i < users.length; i++) {
            vars.isUserUnderwater[i] = size.isUserUnderwater(users[i]);
        }
        vars.senderCollateralAmount = weth.balanceOf(sender);
        vars.senderBorrowAmount = usdc.balanceOf(sender);
        vars.sizeCollateralAmount = weth.balanceOf(address(size));
        vars.sizeBorrowAmount = usdc.balanceOf(address(variablePool));
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
