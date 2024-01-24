// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

import {InterestMath} from "@src/libraries/variable/InterestMath.sol";
import {RAY, WadRayMath} from "@src/libraries/variable/WadRayMathLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract BorrowVariableTest is BaseTest {
    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_DUE_DATE = 12;
    uint256 private constant MAX_AMOUNT = 100e18;

    function test_BorrowVariable_borrowVariable() public {
        _depositVariable(alice, usdc, 100e6);
        _depositVariable(bob, weth, 10e18);

        Vars memory _before = _state();

        uint256 amount = 50e18;
        uint256 debt = amount;
        _borrowVariable(bob, 50e18);

        Vars memory _after = _state();

        assertEq(_before.bob.variableCollateralAmount, 10e18);
        assertEq(_after.alice.variableBorrowAmount, _before.alice.variableBorrowAmount);
        assertEq(_after.bob.variableBorrowAmount, _before.bob.variableBorrowAmount + amount);
        assertEq(_after.bob.variableDebtAmount, debt);
    }

    function test_BorrowVariable_borrowVariable_deposit_time_borrow() public {
        _depositVariable(alice, usdc, 100e6);
        _depositVariable(bob, weth, 10e18);

        Vars memory _before = _state();

        vm.warp(block.timestamp + 1 days);

        Vars memory _time = _state();

        uint256 amount = 50e18;
        uint256 indexSupplyRAY = InterestMath.linearInterestRAY(RAY, 1 days);
        uint256 indexBorrowRAY = InterestMath.compoundInterestRAY(RAY, 1 days);
        uint256 scaledSupplyAmount = WadRayMath.rayDiv(amount, indexSupplyRAY);
        uint256 scaledDebt = WadRayMath.rayDiv(amount, indexBorrowRAY);
        uint256 scaledAmount = WadRayMath.rayDiv(amount, indexBorrowRAY);
        _borrowVariable(bob, 50e18);

        Vars memory _after = _state();

        // FIXME UR math is not correct
        // assertEq(_time.alice.variableBorrowAmount, 42 + scaledSupplyAmount);
        assertEq(_after.alice.variableBorrowAmount, _time.alice.variableBorrowAmount);
        assertEq(_after.bob.variableBorrowAmount, _before.bob.variableBorrowAmount + amount);
        assertEq(_after.bob.variableDebtAmount, amount);
        assertEq(_after.bob.scaledDebtAmount, scaledDebt);
        assertEq(_after.bob.scaledBorrowAmount, scaledAmount);
    }

    function test_BorrowVariable_borrowVariable_deposit_borrow_time() public {}

    function test_BorrowVariable_borrowVariable_deposit_time_borrow_time() public {}

    // function test_BorrowVariable_borrowVariable_properties() public {
    //     _depositVariable(alice, 100e18, 100e18);
    //     _depositVariable(bob, 100e18, 100e18);
    //     _depositVariable(candy, 100e18, 100e18);
    //     _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
    //     _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
    //     uint256 loanId = _borrowVariable(bob, alice, 30e18, 12);
    //     uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
    //     virtualCollateralFixedLoanIds[0] = loanId;

    //     Vars memory _before = _state();

    //     uint256 loanId2 = _borrowVariable(alice, candy, 30e18, 12, virtualCollateralFixedLoanIds);

    //     Vars memory _after = _state();

    //     assertLt(_after.candy.borrowAmount, _before.candy.borrowAmount);
    //     assertGt(_after.alice.borrowAmount, _before.alice.borrowAmount);
    //     assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
    //     assertEq(_after.alice.debtAmount, _before.alice.debtAmount);
    //     assertEq(_after.bob, _before.bob);
    //     assertTrue(!size.isFOL(loanId2));
    // }

    // function test_BorrowVariable_borrowVariable_reverts_if_free_eth_is_lower_than_locked_amount() public {
    //     _depositVariable(alice, 100e18, 100e18);
    //     _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
    //     FixedLoanOffer memory loanOffer = size.getUserView(alice).user.loanOffer;
    //     uint256 amount = 100e18;
    //     uint256 dueDate = 12;
    //     uint256 r = PERCENT + loanOffer.getRate(dueDate);
    //     uint256 faceValue = Math.mulDivUp(r, amount, PERCENT);
    //     uint256 faceValueOpening = Math.mulDivUp(faceValue, size.config().crOpening, PERCENT);
    //     uint256 maxCollateralToLock = Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
    //     vm.startPrank(bob);
    //     uint256[] memory virtualCollateralFixedLoanIds;
    //     vm.expectRevert(abi.encodeWithSelector(Errors.INSUFFICIENT_COLLATERAL.selector, 0, maxCollateralToLock));
    //     size.borrowVariable(
    //         BorrowVariableParams({
    //             lender: alice,
    //             amount: 100e18,
    //             dueDate: 12,
    //             exactAmountIn: false,
    //             virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
    //         })
    //     );
    // }
}
