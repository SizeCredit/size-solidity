// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";

import {Vars} from "@test/BaseTest.sol";
import {BaseTestGenericMarket} from "@test/BaseTestGenericMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract GenericMarket_sUSDe_USDC_Test is BaseTestGenericMarket {
    function setUp() public virtual override {
        this.setUp_sUSDe_USDC();
    }

    function test_GenericMarket_sUSDe_USDC_decimals() public {
        assertEq(size.data().collateralToken.decimals(), 18);
        assertEq(size.data().borrowAToken.decimals(), 6);
        assertEq(size.data().debtToken.decimals(), 6);
    }

    function test_GenericMarket_sUSDe_USDC_debtTokenAmountToCollateralTokenAmount() public {
        assertEq(size.debtTokenAmountToCollateralTokenAmount(1.1e6), 0.9999e18 + 1);
    }

    function test_GenericMarket_sUSDe_USDC_deposit_eth_reverts() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.borrowATokenBalance, 0);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.startPrank(alice);

        vm.expectRevert();
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));
    }

    function test_GenericMarket_sUSDe_USDC_collateralRatio() public {
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("liquidationRewardPercent", 0);

        _deposit(alice, address(borrowToken), 1000e6);
        _deposit(bob, address(collateralToken), 1000e18);
        _deposit(liquidator, address(borrowToken), 2000e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        assertEqApprox(size.collateralRatio(bob), 5.5e18, 0.01e18);

        assertEq(_state().bob.debtBalance, 200e6);

        _setPrice(priceFeed.getPrice() / 10);
        assertEqApprox(size.collateralRatio(bob), 0.55e18, 0.01e18);

        Vars memory _before = _state();

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance + 1000e18);
    }
}
