// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Math} from "@src/libraries/Math.sol";
import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {MoveToVariablePoolParams} from "@src/libraries/fixed/actions/MoveToVariablePool.sol";

contract MoveToVariablePoolTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;

    function test_MoveToVariablePool_moveToVariablePool_borrows_from_VP() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 150e18);
        _deposit(candy, address(usdc), 100e6);
        _depositVariable(alice, address(usdc), 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);

        vm.warp(block.timestamp + 12);

        Vars memory _before = _state();
        uint256 loansBefore = size.activeFixedLoans();
        FixedLoan memory loanBefore = size.getFixedLoan(loanId);
        uint256 variablePoolWETHBefore = weth.balanceOf(address(size.generalConfig().variablePool));

        uint256 assignedCollateral =
            Math.mulDivDown(_before.bob.collateralAmount, loanBefore.faceValue, _before.bob.debtAmount);

        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));

        Vars memory _after = _state();
        uint256 loansAfter = size.activeFixedLoans();
        FixedLoan memory loanAfter = size.getFixedLoan(loanId);
        uint256 variablePoolWETHAfter = weth.balanceOf(address(size.generalConfig().variablePool));

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - assignedCollateral);
        assertEq(variablePoolWETHAfter, variablePoolWETHBefore + assignedCollateral);
        assertTrue(!loanBefore.repaid);
        assertTrue(loanAfter.repaid);
    }

    function test_MoveToVariablePool_moveToVariablePool_fails_if_VP_does_not_have_enough_liquidity() internal {}
}
