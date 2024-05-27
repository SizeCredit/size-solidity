// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {PERCENT} from "@src/libraries/Math.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {Vars} from "@test/BaseTestGeneral.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyCreditMarketTest is BaseTest {
    function test_BuyCreditMarket_parameter_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _sellCreditLimit(alice, 0.03e18, block.timestamp + 10 days);
        _sellCreditLimit(bob, 0.03e18, block.timestamp + 10 days);
        _sellCreditLimit(candy, 0.03e18, block.timestamp + 10 days);
        _sellCreditLimit(james, 0.03e18, block.timestamp + 365 days);
        uint256 debtPositionId = _buyCreditMarket(alice, candy, RESERVED_ID, 40e6, block.timestamp + 10 days, false);

        uint256 deadline = block.timestamp;
        uint256 amount = 50e6;
        uint256 dueDate = block.timestamp + 10 days;
        bool exactAmountIn = false;

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_BORROW_OFFER.selector, address(0)));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: address(0),
                creditPositionId: RESERVED_ID,
                amount: amount,
                dueDate: dueDate,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 0, 5e6));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 0,
                dueDate: dueDate,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                dueDate: 0,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 1e6, size.riskConfig().minimumCreditBorrowAToken
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 1e6,
                dueDate: block.timestamp + 365 days,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.stopPrank();
        vm.startPrank(james);

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROWER_IS_NOT_LENDER.selector, james, alice));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: creditPositionId,
                amount: 20e6,
                dueDate: dueDate,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_NOT_COMPATIBLE.selector, block.timestamp + 4 days, block.timestamp + 10 days
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: creditPositionId,
                amount: 100e6,
                dueDate: block.timestamp + 4 days,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, deadline - 1));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 20e6,
                dueDate: block.timestamp + 10 days,
                deadline: deadline - 1,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        _sellCreditLimit(bob, 0, block.timestamp + 365 days);
        _sellCreditLimit(candy, 0, block.timestamp + 365 days);
        uint256 debtPositionId2 = _buyCreditMarket(alice, candy, RESERVED_ID, 10e6, block.timestamp + 365 days, false);
        creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _repay(candy, debtPositionId2);

        uint256 cr = size.collateralRatio(candy);

        vm.startPrank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, creditPositionId, LoanStatus.REPAID, cr
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: creditPositionId,
                amount: 10e6,
                dueDate: block.timestamp + 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();
    }
}
