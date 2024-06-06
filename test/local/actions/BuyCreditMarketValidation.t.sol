// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {PERCENT} from "@src/libraries/Math.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyCreditMarketTest is BaseTest {
    function test_BuyCreditMarket_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _sellCreditLimit(alice, 0.03e18, 10 days);
        _sellCreditLimit(bob, 0.03e18, 10 days);
        _sellCreditLimit(candy, 0.03e18, 10 days);
        _sellCreditLimit(james, 0.03e18, 365 days);
        uint256 debtPositionId = _buyCreditMarket(alice, candy, RESERVED_ID, 40e6, 10 days, false);

        uint256 deadline = block.timestamp;
        uint256 amount = 50e6;
        uint256 tenor = 10 days;
        bool exactAmountIn = false;

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_BORROW_OFFER.selector, address(0)));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: address(0),
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
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
                tenor: tenor,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TENOR_OUT_OF_RANGE.selector, 0, size.riskConfig().minTenor, size.riskConfig().maxTenor
            )
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 100e6,
                tenor: 0,
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
                tenor: 365 days,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.stopPrank();
        vm.startPrank(james);

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: address(0),
                creditPositionId: creditPositionId,
                amount: 20e6,
                tenor: type(uint256).max,
                deadline: deadline,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_CREDIT.selector, 100e6, 20e6));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: creditPositionId,
                amount: 100e6,
                tenor: 4 days,
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
                tenor: 10 days,
                deadline: deadline - 1,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        uint256 apr = size.getBorrowOfferAPR(james, 365 days);

        vm.startPrank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.APR_LOWER_THAN_MIN_APR.selector, apr, apr + 1));
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: RESERVED_ID,
                amount: 20e6,
                tenor: 365 days,
                deadline: deadline,
                minAPR: apr + 1,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();

        _sellCreditLimit(bob, 0, 365 days);
        _sellCreditLimit(candy, 0, 365 days);
        uint256 debtPositionId2 = _buyCreditMarket(alice, candy, RESERVED_ID, 10e6, 365 days, false);
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
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: exactAmountIn
            })
        );
        vm.stopPrank();
    }
}
