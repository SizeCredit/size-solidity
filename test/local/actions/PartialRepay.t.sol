// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {PartialRepay} from "@src/market/libraries/actions/PartialRepay.sol";

import {PartialRepayParams} from "@src/market/libraries/actions/PartialRepay.sol";
import {SellCreditLimitParams} from "@src/market/libraries/actions/SellCreditLimit.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract PartialRepayTest is BaseTest {
    function test_PartialRepay_partialRepay_reduces_repaid_loan_debt_and_loan_credit() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 400e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.5e18));

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 120e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getUserView(bob).borrowATokenBalance, 120e6);
        assertEq(size.getUserView(bob).debtBalance, 180e6);

        uint256[] memory receivableCreditPositionIds = new uint256[](1);
        receivableCreditPositionIds[0] = type(uint256).max;

        _deposit(bob, usdc, 100e6);

        _partialRepay(bob, creditPositionId, 70e6, bob);

        assertEq(size.getUserView(bob).borrowATokenBalance, 120e6 + 100e6 - 70e6, 150e6);
        assertEq(size.getUserView(bob).debtBalance, 180e6 - 70e6, 110e6);
    }

    function test_PartialRepay_partialRepay_is_permissionless() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 400e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.5e18));

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 120e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getUserView(bob).borrowATokenBalance, 120e6);
        assertEq(size.getUserView(bob).debtBalance, 180e6);

        uint256[] memory receivableCreditPositionIds = new uint256[](1);
        receivableCreditPositionIds[0] = type(uint256).max;

        _deposit(james, usdc, 100e6);

        vm.prank(james);
        size.partialRepay(
            PartialRepayParams({creditPositionWithDebtToRepayId: creditPositionId, amount: 10e6, borrower: bob})
        );

        assertEq(size.getUserView(bob).debtBalance, 180e6 - 10e6, 170e6);
    }
}
