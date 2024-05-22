// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Math} from "@src/libraries/Math.sol";

import {Vars} from "@test/BaseTestGeneral.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyCreditMarketTest is BaseTest {

    function test_BuyCreditMarket_buy_existing_credit() public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _lendAsLimitOrder(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _borrow(bob, alice, 975.94e6, block.timestamp + 6 * 30 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];
        uint256 debtPositionId2 = _borrow(james, candy, 1000.004274e6, block.timestamp + 7 * 30 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[1];

        assertEq(size.getDebtPosition(debtPositionId1).faceValue, 1000.004274e6);
        assertEq(_state().alice.borrowATokenBalance, 24.06e6);
        assertEqApprox(_state().james.borrowATokenBalance, 2000e6, 0.01e6);

        // _buyMarketCredit(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).faceValue, false);
        _buyCreditMarket(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).faceValue, false, 0, address(0)); // Buying credit

        assertEqApprox(_state().james.borrowATokenBalance, 2000e6 - 980.66e6, 0.01e6);

        uint256 creditPositionId1_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[2];
        _compensate(james, creditPositionId2_1, creditPositionId1_2);

        assertEqApprox(_state().alice.borrowATokenBalance, 1004e6, 1e6);
    }
    
    function test_BuyCreditMarket_lend_to_borrower() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        uint256 rate = 0.03e18;
        _borrowAsLimitOrder(alice, int256(rate), block.timestamp + 365 days);

        uint256 issuanceValue = 10e6;
        uint256 faceValue = Math.mulDivUp(issuanceValue, PERCENT + rate, PERCENT);
        uint256 dueDate = block.timestamp + 365 days;
        uint256 amountIn = Math.mulDivUp(faceValue, PERCENT, PERCENT + rate);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _buyCreditMarket(bob, 0, faceValue, false, dueDate, alice);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - size.getSwapFee(amountIn, dueDate)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(
            _after.alice.debtBalance, _before.alice.debtBalance + faceValue + size.feeConfig().overdueLiquidatorReward
        );
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getOverdueDebt(debtPositionId), faceValue + size.feeConfig().overdueLiquidatorReward);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }
}

