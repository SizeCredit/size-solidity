// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {Events} from "@src/libraries/Events.sol";
import {CREDIT_POSITION_ID_START, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract SwapDataTest is BaseTest {
    function test_SwapData_borrowerAPR_lenderAPR() public {
        // I borrow for 6 months at 5% from you.
        // You are now lending at 5%.
        // You exit to someone demanding 4%.
        // New lender now earning 4%, while I’m still locked into the 5% deal.
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.05e18));

        _deposit(bob, weth, 200e18);

        uint256 tenor = 365 days;
        uint256 cash = 100e6;
        uint256 credit = 105e6;

        vm.expectEmit();
        emit Events.SwapData(CREDIT_POSITION_ID_START, bob, alice, credit, cash, cash, 0, 0, tenor);

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, cash, tenor, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(creditPositionId, CREDIT_POSITION_ID_START);
        assertEq(credit, size.getDebtPosition(debtPositionId).futureValue);
        assertEq(size.getAPR(cash, credit, tenor), 0.05e18);

        _deposit(candy, usdc, 200e6);
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.04e18));

        uint256 newCash = 100.961538e6;
        vm.expectEmit();
        emit Events.SwapData(creditPositionId, alice, candy, credit, newCash, newCash, 0, 0, tenor);

        _sellCreditMarket(alice, candy, creditPositionId, credit, tenor, true);

        assertEq(credit, size.getDebtPosition(debtPositionId).futureValue);
        assertEqApprox(size.getAPR(newCash, credit, tenor), 0.04e18, 0.001e18);
    }

    function test_SwapData_apr_with_fees() public {
        // The formula is correct but the cash for the lender and the borrower are different because of the swap fee leading to different APRs
        // Example
        // - Lender lends out 100 and gets a credit for 110 due 1Y so his APR is 10%
        // - Borrower does not receive 100 though but 100 - 0.5 = 99.5 since the fee is 0.5% APR on the issuance value which is the cash he would have received if no fee was charged = the amount disbursed by the lender so his APR is 10.5%
        // When the fragmentation fee is charged, the cash to consider is the amount after that fee has been charged
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));

        _deposit(bob, weth, 200e18);

        uint256 tenor = 365 days;
        uint256 cashIn = 100e6;
        uint256 credit = 110e6;
        uint256 swapFee = 0.5e6;
        uint256 fragmentationFee = 0;
        uint256 cashOut = cashIn - swapFee;

        vm.expectEmit();
        emit Events.SwapData(
            CREDIT_POSITION_ID_START, bob, alice, credit, cashIn, cashOut, swapFee, fragmentationFee, tenor
        );
        _sellCreditMarket(bob, alice, RESERVED_ID, credit, tenor, true);

        uint256 lenderAPR = 0.1e18;
        uint256 borrowerAPR = 0.105e18;

        assertEq(lenderAPR, size.getAPR(cashIn, credit, tenor));
        assertEqApprox(borrowerAPR, size.getAPR(cashOut, credit, tenor), 0.001e18);
    }
}
