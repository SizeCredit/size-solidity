// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START} from "@src/market/libraries/LoanLibrary.sol";
import {
    BuyCreditMarketOnBehalfOfParams, BuyCreditMarketParams
} from "@src/market/libraries/actions/BuyCreditMarket.sol";

contract AuthorizationBuyCreditMarketTest is BaseTest {
    function test_AuthorizationBuyCreditMarket_buyCreditMarketOnBehalfOf() public {
        _setAuthorization(bob, candy, Authorization.getActionsBitmap(Action.BUY_CREDIT_MARKET));

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        uint256 rate = 0.03e18;
        _sellCreditLimit(alice, block.timestamp + 365 days, int256(rate), 365 days);

        uint256 issuanceValue = 10e6;
        uint256 futureValue = Math.mulDivUp(issuanceValue, PERCENT + rate, PERCENT);
        uint256 tenor = 365 days;
        uint256 amountIn = Math.mulDivUp(futureValue, PERCENT, PERCENT + rate);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        vm.prank(candy);
        size.buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({
                params: BuyCreditMarketParams({
                    borrower: alice,
                    creditPositionId: RESERVED_ID,
                    amount: amountIn,
                    tenor: tenor,
                    deadline: block.timestamp,
                    minAPR: 0,
                    exactAmountIn: true
                }),
                onBehalfOf: bob,
                recipient: candy
            })
        );
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        uint256 debtPositionId = DEBT_POSITION_ID_START + debtPositionsCount - 1;
        uint256 creditPositionId = CREDIT_POSITION_ID_START + creditPositionsCount - 1;

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(
            _after.alice.borrowATokenBalance,
            _before.alice.borrowATokenBalance + amountIn - size.getSwapFee(amountIn, tenor)
        );
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + futureValue);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
        assertEq(size.getCreditPosition(creditPositionId).lender, candy);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, block.timestamp + tenor);
    }

    function test_AuthorizationBuyCreditMarket_validation() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.BUY_CREDIT_MARKET)
        );
        vm.prank(alice);
        size.buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({
                params: BuyCreditMarketParams({
                    borrower: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 100e6,
                    tenor: 365 days,
                    deadline: block.timestamp,
                    minAPR: 0,
                    exactAmountIn: true
                }),
                onBehalfOf: bob,
                recipient: candy
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        vm.prank(alice);
        size.buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({
                params: BuyCreditMarketParams({
                    borrower: address(0),
                    creditPositionId: RESERVED_ID,
                    amount: 100e6,
                    tenor: 365 days,
                    deadline: block.timestamp,
                    minAPR: 0,
                    exactAmountIn: true
                }),
                onBehalfOf: alice,
                recipient: address(0)
            })
        );
    }
}
