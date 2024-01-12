// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {BaseTest, Vars} from "./BaseTest.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {FixedLoan, FixedLoanLibrary, RESERVED_ID} from "@src/libraries/FixedLoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedLoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract BorrowAsMarketOrderTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;
    using FixedLoanLibrary for FixedLoan;

    uint256 private constant MAX_RATE = 2e18;
    uint256 private constant MAX_DUE_DATE = 12;
    uint256 private constant MAX_AMOUNT = 100e18;

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_real_collateral() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        FixedLoanOffer memory offerBefore = size.getUserView(alice).user.loanOffer;

        Vars memory _before = _state();

        uint256 amount = 10e18;
        uint256 dueDate = 12;

        _borrowAsMarketOrder(bob, alice, amount, dueDate);

        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtOpening = Math.mulDivUp(debt, size.f().crOpening, PERCENT);
        uint256 minimumCollateral = Math.mulDivUp(debtOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        Vars memory _after = _state();
        FixedLoanOffer memory offerAfter = size.getUserView(alice).user.loanOffer;

        assertGt(_before.bob.collateralAmount, minimumCollateral);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount - amount);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount + amount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.bob.debtAmount, debt);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amount);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_real_collateral(
        uint256 amount,
        uint256 rate,
        uint256 dueDate
    ) public {
        amount = bound(amount, 1, MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        dueDate = bound(dueDate, block.timestamp, block.timestamp + MAX_DUE_DATE - 1);

        amount = 10e18;
        rate = 0.03e18;
        dueDate = 12;

        _deposit(alice, MAX_AMOUNT, MAX_AMOUNT);
        _deposit(bob, MAX_AMOUNT, MAX_AMOUNT);

        _lendAsLimitOrder(alice, MAX_AMOUNT, block.timestamp + MAX_DUE_DATE, rate, MAX_DUE_DATE);
        FixedLoanOffer memory offerBefore = size.getUserView(alice).user.loanOffer;

        Vars memory _before = _state();

        _borrowAsMarketOrder(bob, alice, amount, dueDate);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + rate), PERCENT);
        uint256 debtOpening = Math.mulDivUp(debt, size.f().crOpening, PERCENT);
        uint256 minimumCollateral = Math.mulDivUp(debtOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        Vars memory _after = _state();
        FixedLoanOffer memory offerAfter = size.getUserView(alice).user.loanOffer;

        assertGt(_before.bob.collateralAmount, minimumCollateral);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount - amount);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount + amount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.bob.debtAmount, debt);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amount);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        uint256 amount = 30e18;
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 60e18, 12);
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId;

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amount, 12, virtualCollateralFixedLoanIds);

        Vars memory _after = _state();

        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount - amount);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + amount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount);
        assertEq(_after.bob, _before.bob);
        assertTrue(!size.isFOL(loanId2));
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral(
        uint256 amount,
        uint256 rate,
        uint256 dueDate
    ) public {
        amount = bound(amount, MAX_AMOUNT / 10, 2 * MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy
        rate = bound(rate, 0, MAX_RATE);
        dueDate = bound(dueDate, block.timestamp, block.timestamp + MAX_DUE_DATE - 1);

        _deposit(alice, MAX_AMOUNT, MAX_AMOUNT);
        _deposit(bob, MAX_AMOUNT, MAX_AMOUNT);
        _deposit(candy, MAX_AMOUNT, MAX_AMOUNT);

        _lendAsLimitOrder(alice, MAX_AMOUNT, block.timestamp + MAX_DUE_DATE, rate, MAX_DUE_DATE);
        _lendAsLimitOrder(candy, MAX_AMOUNT, block.timestamp + MAX_DUE_DATE, rate, MAX_DUE_DATE);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, dueDate);
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId;

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amount, dueDate, virtualCollateralFixedLoanIds);

        Vars memory _after = _state();

        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount - amount);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + amount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount);
        assertEq(_after.bob, _before.bob);
        assertTrue(!size.isFOL(loanId2));
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_and_real_collateral() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        FixedLoanOffer memory loanOffer = size.getUserView(candy).user.loanOffer;
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId;

        Vars memory _before = _state();

        uint256 dueDate = 12;
        uint256 amountFixedLoanId2 = 30e18;
        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amountFixedLoanId2, dueDate, virtualCollateralFixedLoanIds);
        FixedLoan memory loan2 = size.getFixedLoan(loanId2);

        Vars memory _after = _state();

        uint256 r = PERCENT + loanOffer.getRate(dueDate);

        uint256 faceValue = Math.mulDivUp(r, (amountFixedLoanId2 - amountFixedLoanId1), PERCENT);
        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.f().crOpening, PERCENT);
        uint256 minimumCollateral = Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertGt(_before.bob.collateralAmount, minimumCollateral);
        assertLt(_after.candy.borrowAmount, _before.candy.borrowAmount);
        assertGt(_after.alice.borrowAmount, _before.alice.borrowAmount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount + faceValue);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isFOL(loanId2));
        assertEq(loan2.faceValue, faceValue);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_and_real_collateral(
        uint256 amountFixedLoanId1,
        uint256 amountFixedLoanId2
    ) public {
        amountFixedLoanId1 = bound(amountFixedLoanId1, MAX_AMOUNT / 10, 2 * MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy
        amountFixedLoanId2 = bound(amountFixedLoanId2, 3 * MAX_AMOUNT / 10, 3 * 2 * MAX_AMOUNT / 10); // arbitrary divisor so that user does not get unhealthy

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        uint256 loanId1 = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId1;

        uint256 dueDate = 12;
        uint256 r = PERCENT + size.getUserView(candy).user.loanOffer.getRate(dueDate);
        uint256 deltaAmountOut = (
            Math.mulDivUp(r, amountFixedLoanId2, PERCENT) > size.getFixedLoan(loanId1).getCredit()
        ) ? Math.mulDivDown(size.getFixedLoan(loanId1).getCredit(), PERCENT, r) : amountFixedLoanId2;
        uint256 faceValue = Math.mulDivUp(r, amountFixedLoanId2 - deltaAmountOut, PERCENT);

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, amountFixedLoanId2, dueDate, virtualCollateralFixedLoanIds);

        Vars memory _after = _state();

        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.f().crOpening, PERCENT);
        uint256 minimumCollateralAmount =
            Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertGt(_before.bob.collateralAmount, minimumCollateralAmount);
        assertLt(_after.candy.borrowAmount, _before.candy.borrowAmount);
        assertGt(_after.alice.borrowAmount, _before.alice.borrowAmount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount + faceValue);
        assertEq(_after.bob, _before.bob);
        assertTrue(size.isFOL(loanId2));
        assertEq(size.getFixedLoan(loanId2).faceValue, faceValue);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_with_virtual_collateral_properties() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 30e18, 12);
        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId;

        Vars memory _before = _state();

        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, 30e18, 12, virtualCollateralFixedLoanIds);

        Vars memory _after = _state();

        assertLt(_after.candy.borrowAmount, _before.candy.borrowAmount);
        assertGt(_after.alice.borrowAmount, _before.alice.borrowAmount);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount);
        assertEq(_after.bob, _before.bob);
        assertTrue(!size.isFOL(loanId2));
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_reverts_if_free_eth_is_lower_than_locked_amount() public {
        _deposit(alice, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        FixedLoanOffer memory loanOffer = size.getUserView(alice).user.loanOffer;
        uint256 amount = 100e18;
        uint256 dueDate = 12;
        uint256 r = PERCENT + loanOffer.getRate(dueDate);
        uint256 faceValue = Math.mulDivUp(r, amount, PERCENT);
        uint256 faceValueOpening = Math.mulDivUp(faceValue, size.f().crOpening, PERCENT);
        uint256 maxCollateralToLock = Math.mulDivUp(faceValueOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        vm.startPrank(bob);
        uint256[] memory virtualCollateralFixedLoanIds;
        vm.expectRevert(abi.encodeWithSelector(Errors.INSUFFICIENT_COLLATERAL.selector, 0, maxCollateralToLock));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: 100e18,
                dueDate: 12,
                exactAmountIn: false,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_reverts_if_lender_cannot_transfer_borrowAsset() public {
        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);

        _withdraw(alice, usdc, 999e6);

        uint256 amount = 10e18;
        uint256 dueDate = 12;

        vm.startPrank(bob);
        uint256[] memory virtualCollateralFixedLoanIds;
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 1e18, 10e18));
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: false,
                virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
            })
        );
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_does_not_create_new_SOL_if_lender_tries_to_exit_fully_exited_SOL(
    ) public {
        _setPrice(1e18);

        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.03e18, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0.03e18, 12);
        uint256 folId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _borrowAsMarketOrder(alice, candy, 100e18, 12, [folId]);

        uint256 loansBefore = size.activeFixedLoans();
        Vars memory _before = _state();

        _borrowAsMarketOrder(alice, james, 100e18, 12, [folId]);

        uint256 loansAfter = size.activeFixedLoans();
        Vars memory _after = _state();

        assertEq(loansAfter, loansBefore + 1);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 100e18);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount + 103e18);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_SOL_of_SOL_creates_with_correct_folId() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 200e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 49e18, 12, [loanId]);
        uint256 solId2 = _borrowAsMarketOrder(candy, bob, 42e18, 12, [solId]);

        assertEq(size.getFixedLoan(loanId).folId, RESERVED_ID);
        assertEq(size.getFixedLoan(solId).folId, loanId);
        assertEq(size.getFixedLoan(solId2).folId, loanId);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_SOL_credit_is_decreased_after_exit() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 200e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 49e18, 12, [loanId]);

        FixedLoan memory solBefore = size.getFixedLoan(solId);

        _borrowAsMarketOrder(candy, bob, 40e18, 12, [solId]);

        FixedLoan memory solAfter = size.getFixedLoan(solId);

        assertEq(solAfter.getCredit(), solBefore.getCredit() - 40e18);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_SOL_cannot_be_fully_exited_twice() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 200e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _borrowAsMarketOrder(alice, candy, 100e18, 12, [loanId]);

        console.log("User attempts to fully exit twice, but a FOL is attempted to be craeted, which reverts");

        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](1);
        virtualCollateralFixedLoanIds[0] = loanId;
        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: james,
            amount: 100e18,
            dueDate: 12,
            exactAmountIn: false,
            virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
        });
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INSUFFICIENT_COLLATERAL.selector, 0, 150e18));
        size.borrowAsMarketOrder(params);
    }

    function test_BorrowAsMarketOrder_borrowAsMarketOrder_does_not_create_loans_if_dust_amount() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.1e18, 12);

        Vars memory _before = _state();

        uint256 amount = 1;
        uint256 dueDate = 12;

        _borrowAsMarketOrder(bob, alice, amount, dueDate, true);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.bob, _before.bob);
        assertEq(_after.bob.debtAmount, 0);
        assertEq(_after.protocolCollateralAmount, _before.protocolCollateralAmount);
        assertEq(size.activeFixedLoans(), 0);
    }
}
