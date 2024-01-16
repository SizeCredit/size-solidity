// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {Vars} from "./BaseTestGeneric.sol";

import {Math} from "@src/libraries/MathLibrary.sol";
import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {MoveToVariablePoolParams} from "@src/libraries/fixed/actions/MoveToVariablePool.sol";

contract MoveToVariablePoolTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;

    function test_MoveToVariablePool_moveToVariablePool_creates_new_VP_loan() public {
        // TODO fix this test
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 150e18);
        _deposit(candy, address(usdc), 100e6);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e18, 12);

        vm.warp(block.timestamp + 12);

        Vars memory _before = _state();
        uint256 loansBefore = size.activeFixedLoans();
        // uint256 variableFixedLoansBefore = size.activeVariableFixedLoans();
        FixedLoan memory loanBefore = size.getFixedLoan(loanId);

        uint256 assignedCollateral =
            Math.mulDivDown(_before.bob.collateralAmount, loanBefore.faceValue, _before.bob.debtAmount);

        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));

        Vars memory _after = _state();
        uint256 loansAfter = size.activeFixedLoans();
        // uint256 variableFixedLoansAfter = size.activeVariableFixedLoans();
        FixedLoan memory loanAfter = size.getFixedLoan(loanId);

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        // assertEq(variableFixedLoansAfter, variableFixedLoansBefore + 1);
        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - assignedCollateral);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount + assignedCollateral);
        assertTrue(!loanBefore.repaid);
        assertTrue(loanAfter.repaid);
    }
}
