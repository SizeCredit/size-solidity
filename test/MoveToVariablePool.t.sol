// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";

contract MoveToVariablePoolTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_MoveToVariablePool_moveToVariablePool_creates_new_VP_loan() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 150e18);
        _deposit(candy, address(usdc), 100e6);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e18, 12);

        vm.warp(block.timestamp + 12);

        Vars memory _before = _state();
        uint256 loansBefore = size.activeLoans();
        uint256 variableLoansBefore = size.activeVariableLoans();
        Loan memory loanBefore = size.getLoan(loanId);

        uint256 assignedCollateral =
            FixedPointMathLib.mulDivDown(_before.bob.collateralAmount, loanBefore.FV, _before.bob.debtAmount);

        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));

        Vars memory _after = _state();
        uint256 loansAfter = size.activeLoans();
        uint256 variableLoansAfter = size.activeVariableLoans();
        Loan memory loanAfter = size.getLoan(loanId);

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(variableLoansAfter, variableLoansBefore + 1);
        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - assignedCollateral);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount + assignedCollateral);
        assertTrue(!loanBefore.repaid);
        assertTrue(loanAfter.repaid);
    }
}
