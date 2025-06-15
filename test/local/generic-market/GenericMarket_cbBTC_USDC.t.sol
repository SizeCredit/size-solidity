// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";

import {Vars} from "@test/BaseTest.sol";
import {BaseTestGenericMarket} from "@test/BaseTestGenericMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract GenericMarket_cbBTC_USDC_Test is BaseTestGenericMarket {
    function setUp() public virtual override {
        this.setUp_cbBTC_USDC();
    }

    function test_GenericMarket_cbBTC_USDC_decimals() public view {
        assertEq(size.data().collateralToken.decimals(), 8);
        assertEq(size.data().borrowTokenVault.decimals(), 6);
        assertEq(size.data().debtToken.decimals(), 6);
    }

    function test_GenericMarket_cbBTC_USDC_debtTokenAmountToCollateralTokenAmount() public view {
        assertEq(size.debtTokenAmountToCollateralTokenAmount(60576e6), 0.9999e8 + 1);
    }

    function test_GenericMarket_cbBTC_USDC_config() public view {
        assertEqApprox(size.feeConfig().fragmentationFee, 5e6, 0.01e6);
        assertEqApprox(size.riskConfig().minimumCreditBorrowToken, 10e6, 0.01e6);
    }

    function test_GenericMarket_cbBTC_USDC_deposit_eth_reverts() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.borrowTokenBalance, 0);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.startPrank(alice);

        vm.expectRevert();
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));
    }

    function test_GenericMarket_cbBTC_USDC_collateralRatio() public {
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("liquidationRewardPercent", 0);

        _deposit(alice, address(borrowToken), 60576e6);
        _deposit(bob, address(collateralToken), 1e8);
        _deposit(liquidator, address(borrowToken), 2 * 60576e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.25e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 30288e6, 365 days, false);
        assertEqApprox(size.collateralRatio(bob), 1.6e18, 0.01e18);

        assertEq(_state().bob.debtBalance, 30288e6 + 30288e6 / 4);

        _setPrice(3 * priceFeed.getPrice() / 4);
        assertEqApprox(size.collateralRatio(bob), 1.2e18, 0.01e18);

        Vars memory _before = _state();

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance + ((30288e6 + 30288e6 / 4) * 4 * 0.9999e8 / (3 * 60576e6)) + 1
        );
    }
}
