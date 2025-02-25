// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {Vars} from "@test/BaseTest.sol";
import {BaseTestGenericMarket} from "@test/BaseTestGenericMarket.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract GenericMarket_USDT_cbBTC_Test is BaseTestGenericMarket {
    function setUp() public virtual override {
        this.setUp_USDT_cbBTC();
    }

    function test_GenericMarket_USDT_cbBTC_decimals() public view {
        assertEq(size.data().collateralToken.decimals(), 6);
        assertEq(size.data().borrowAToken.decimals(), 8);
        assertEq(size.data().debtToken.decimals(), 8);
    }

    function test_GenericMarket_USDT_cbBTC_debtTokenAmountToCollateralTokenAmount() public view {
        assertEq(size.debtTokenAmountToCollateralTokenAmount(1e8), 60576e6 + 1);
    }

    function test_GenericMarket_USDT_cbBTC_config() public view {
        assertEqApprox(size.feeConfig().fragmentationFee, 0.00008254e8, 1);
        assertEqApprox(size.riskConfig().minimumCreditBorrowAToken, 0.00016508e8, 1);
        assertEqApprox(size.riskConfig().borrowATokenCap, 16.5e8, 0.1e8);
    }

    function test_GenericMarket_USDT_cbBTC_deposit_eth_reverts() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.borrowATokenBalance, 0);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.startPrank(alice);

        vm.expectRevert();
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));
    }

    function test_GenericMarket_USDT_cbBTC_collateralRatio() public {
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("liquidationRewardPercent", 0);

        _deposit(alice, address(borrowToken), 1e8);
        _deposit(bob, address(collateralToken), 60576e6);
        _deposit(liquidator, address(borrowToken), 2e8);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.5e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 0.4e8, 365 days, false);
        assertEqApprox(size.collateralRatio(bob), 1.667e18, 0.001e18);

        assertEq(_state().bob.debtBalance, 0.6e8);

        _setPrice(75 * priceFeed.getPrice() / 100);
        assertEqApprox(size.collateralRatio(bob), 1.25e18, 0.001e18);

        Vars memory _before = _state();

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance
                + Math.mulDivUp(
                    0.6e8 * 10 ** priceFeed.decimals(),
                    10 ** collateralToken.decimals(),
                    priceFeed.getPrice() * 10 ** borrowToken.decimals()
                )
        );
    }
}
