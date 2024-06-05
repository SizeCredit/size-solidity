// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SellCreditMarketValidationTest is BaseTest {
    function test_SellCreditMarket_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _buyCreditLimit(
            alice, block.timestamp + 10 days, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]
        );
        _buyCreditLimit(
            bob, block.timestamp + 5 days, [int256(0.03e18), int256(0.03e18)], [uint256(1 days), uint256(12 days)]
        );
        _buyCreditLimit(candy, block.timestamp + 10 days, YieldCurveHelper.pointCurve(10 days, 0.03e18));
        _buyCreditLimit(
            james, block.timestamp + 365 days, [int256(0.03e18), int256(0.03e18)], [uint256(10 days), uint256(365 days)]
        );
        uint256 debtPositionId = _sellCreditMarket(alice, candy, RESERVED_ID, 40e6, 10 days, false);

        uint256 deadline = block.timestamp;
        uint256 amount = 50e6;
        uint256 tenor = 10 days;
        bool exactAmountIn = false;

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_LOAN_OFFER.selector, address(0)));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: address(0),
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 0, 5e6));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 0,
                tenor: tenor,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TENOR_OUT_OF_RANGE.selector, 0, size.riskConfig().minTenor, size.riskConfig().maxTenor
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                tenor: 0,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector, block.timestamp + 11 days, block.timestamp + 10 days
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 20e6,
                tenor: 11 days,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 1e6, size.riskConfig().minimumCreditBorrowAToken
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: james,
                creditPositionId: RESERVED_ID,
                amount: 1e6,
                tenor: 365 days,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.stopPrank();
        vm.startPrank(james);

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROWER_IS_NOT_LENDER.selector, james, candy));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: creditPositionId,
                amount: 20e6,
                tenor: tenor,
                deadline: deadline,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.APR_GREATER_THAN_MAX_APR.selector, 0.03e18, 0.01e18));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: james,
                creditPositionId: creditPositionId,
                amount: 20e6,
                tenor: type(uint256).max,
                deadline: deadline,
                maxAPR: 0.01e18,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, deadline - 1));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: james,
                creditPositionId: creditPositionId,
                amount: 20e6,
                tenor: type(uint256).max,
                deadline: deadline - 1,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId2 = _sellCreditMarket(alice, candy, RESERVED_ID, 10e6, 365 days, false);
        creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        uint256 credit = size.getCreditPosition(creditPositionId).credit;

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_CREDIT.selector, 1000e6, credit));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: bob,
                creditPositionId: creditPositionId,
                amount: 1000e6,
                tenor: 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        _repay(alice, debtPositionId2);

        uint256 cr = size.collateralRatio(alice);

        vm.startPrank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, creditPositionId, LoanStatus.REPAID, cr
            )
        );
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: bob,
                creditPositionId: creditPositionId,
                amount: 10e6,
                tenor: 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();
    }
}
