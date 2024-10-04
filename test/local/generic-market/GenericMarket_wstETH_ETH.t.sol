// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";

import {Vars} from "@test/BaseTest.sol";
import {BaseTestGenericMarket} from "@test/BaseTestGenericMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract GenericMarket_wstETH_ETH_Test is BaseTestGenericMarket {
    function setUp() public virtual override {
        this.setUp_wstETH_ETH();
    }

    function test_GenericMarket_wstETH_ETH_decimals() public {
        assertEq(size.data().collateralToken.decimals(), 18);
        assertEq(size.data().borrowAToken.decimals(), 18);
        assertEq(size.data().debtToken.decimals(), 18);
    }

    function test_GenericMarket_wstETH_ETH_config() public {
        assertEqApprox(size.feeConfig().fragmentationFee, 0.00197e18, 0.0001e18);
        assertEqApprox(size.riskConfig().minimumCreditBorrowAToken, 0.00377e18, 0.0001e18);
        assertEqApprox(size.riskConfig().borrowATokenCap, 377e18, 1e18);
    }

    function test_GenericMarket_wstETH_ETH_debtTokenAmountToCollateralTokenAmount() public {
        assertEqApprox(size.debtTokenAmountToCollateralTokenAmount(1e18), 0.848e18, 0.001e18);
    }

    function test_GenericMarket_wstETH_ETH_deposit_eth_does_not_revert() public {
        _setLiquidityIndex(address(weth), 1e27);

        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.borrowATokenBalance, 0);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.prank(alice);
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));

        assertEq(address(alice).balance, 0);
        assertEq(_state().alice.borrowATokenBalance, 1 ether);
        assertEq(_state().alice.collateralTokenBalance, 0);
    }

    function test_GenericMarket_wstETH_ETH_collateralRatio() public {
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("liquidationRewardPercent", 0);

        _deposit(alice, address(borrowToken), 1e18);
        _deposit(bob, address(collateralToken), 2e18);
        _deposit(liquidator, address(borrowToken), 2e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 0.5e18, 365 days, false);
        assertEqApprox(size.collateralRatio(bob), 2.36e18, 0.01e18);

        assertEq(_state().bob.debtBalance, 1e18);

        _setPrice(priceFeed.getPrice() / 5);
        assertEqApprox(size.collateralRatio(bob), 0.47e18, 0.01e18);

        Vars memory _before = _state();

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance + 2e18);
    }
}
