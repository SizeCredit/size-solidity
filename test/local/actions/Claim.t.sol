// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {CreditPosition, DebtPosition, LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

contract ClaimTest is BaseTest {
    function test_Claim_claim_gets_loan_FV_back() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.05e18));
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amountLoanId1, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _repay(bob, debtPositionId);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);

        Vars memory _before = _state();

        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + futureValue);
        assertEq(size.getCreditPosition(creditId).credit, 0);
    }

    function test_Claim_claim_of_exited_loan_gets_credit_back() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 120e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 futureValueExited = 10e6;
        _sellCreditMarket(alice, candy, creditId, futureValueExited, 365 days);
        _repay(bob, debtPositionId);

        Vars memory _before = _state();

        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
        _claim(alice, creditId);

        Vars memory _after = _state();

        uint256 credit = futureValue - futureValueExited;
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + credit);
        assertEq(size.getCreditPosition(creditId).credit, 0);
    }

    function test_Claim_claim_of_CreditPosition_where_DebtPosition_is_repaid_works() public {
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 120e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 exit = 30e6;
        _sellCreditMarket(alice, candy, creditId, exit, 365 days);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(candy, creditId2);

        Vars memory _after = _state();

        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - futureValue);
        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance + exit);
    }

    function test_Claim_claim_twice_does_not_work() public {
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(bob, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - 200e6);

        vm.expectRevert();
        _claim(alice, creditId);
    }

    function test_Claim_claim_is_permissionless() public {
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - 200e6);
        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance);
        assertEq(_after.feeRecipient.collateralTokenBalance, _before.feeRecipient.collateralTokenBalance);
    }

    function test_Claim_claim_of_liquidated_loan_retrieves_borrow_amount() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 120e6);
        _deposit(bob, weth, 320e18);
        _deposit(liquidator, usdc, 10000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _setPrice(0.75e18);

        _liquidate(liquidator, debtPositionId);

        Vars memory _before = _state();

        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + futureValue);
    }

    function test_Claim_claim_at_different_times_may_have_different_interest() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, weth, 160e18);
        _deposit(bob, usdc, 100e6 + size.feeConfig().fragmentationFee);
        _deposit(candy, usdc, 10e6);
        _deposit(liquidator, usdc, 1000e6);
        _buyCreditLimit(bob, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(bob, candy, creditId, 10e6, 12 days);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        Vars memory _s1 = _state();

        assertEq(_s1.alice.borrowATokenBalance, 100e6, "Alice borrowed 100e6");
        assertEq(_s1.size.borrowATokenBalance, 0, "Size has 0");

        _setLiquidityIndex(2e27);
        _repay(alice, debtPositionId);

        Vars memory _s2 = _state();

        assertEq(_s2.alice.borrowATokenBalance, 100e6, "Alice borrowed 100e6 and it 2x, but she repaid 100e6");
        assertEq(
            _s2.size.borrowATokenBalance,
            100e6,
            "Alice repaid amount is now on Size for claiming for DebtPosition/CreditPosition"
        );

        _setLiquidityIndex(8e27);
        _claim(candy, creditId2);

        Vars memory _s3 = _state();

        assertEq(_s3.candy.borrowATokenBalance, 40e6, "Candy borrowed 10e6 4x, so it is now 40e6");
        assertEq(
            _s3.size.borrowATokenBalance,
            360e6,
            "Size had 100e6 for claiming, it 4x to 400e6, and Candy claimed 40e6, now there's 360e6 left for claiming"
        );

        _setLiquidityIndex(16e27);
        _claim(bob, creditId);

        Vars memory _s4 = _state();

        assertEq(
            _s4.bob.borrowATokenBalance,
            80e6 + 800e6,
            "Bob lent 100e6 and was repaid and it 8x, and it borrowed 10e6 and it 8x, so it is now 880e6"
        );
        assertEq(_s4.candy.borrowATokenBalance, 80e6, "Candy borrowed 40e6 2x, so it is now 80e6");
        assertEq(_s4.size.borrowATokenBalance, 0, "Size has 0 because everything was claimed");
    }

    function test_Claim_isClaimable() public {
        _updateConfig("swapFeeAPR", 0);
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 50e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.warp(block.timestamp + 365 days);
        _deposit(alice, usdc, 5e6);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.getLoanStatus, creditPositionId);
        data[1] = abi.encodeCall(size.getCreditPosition, creditPositionId);
        bytes[] memory returnDatas = size.multicall(data);

        bool isClaimable = abi.decode(returnDatas[0], (LoanStatus)) == LoanStatus.REPAID
            && abi.decode(returnDatas[1], (CreditPosition)).credit > 0;
        assertTrue(!isClaimable);

        vm.expectRevert();
        _claim(bob, creditPositionId);

        _repay(alice, debtPositionId);

        returnDatas = size.multicall(data);
        isClaimable = abi.decode(returnDatas[0], (LoanStatus)) == LoanStatus.REPAID
            && abi.decode(returnDatas[1], (CreditPosition)).credit > 0;
        assertTrue(isClaimable);

        _claim(bob, creditPositionId);
    }

    function test_Claim_test_borrow_repay_claim() public {
        _setPrice(1e18);

        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 120e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _deposit(james, weth, 5000e18);

        uint256 debtPositionId = _sellCreditMarket(james, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        (uint256 debtPositions,) = size.getPositionsCount();
        assertGt(debtPositions, 0);
        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        CreditPosition memory creditPosition = size.getCreditPosition(creditPositionId);
        assertEq(creditPosition.credit, debtPosition.futureValue);

        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalance, 100e6);
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.02e18));
        _sellCreditMarket(alice, bob, creditPositionId, 50e6, 365 days);

        vm.expectRevert();
        _claim(alice, creditPositionId);

        _deposit(james, usdc, debtPosition.futureValue);

        _repay(james, debtPositionId);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);

        _claim(alice, creditPositionId);

        vm.expectRevert();
        _claim(alice, creditPositionId);
    }
}
