// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/periphery/FlashLoanLiquidation.sol";
import "./mocks/Mock1InchAggregator.sol";
import "./mocks/MockAavePool.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract FlashLoanLiquidationTest is BaseTest {
    MockAavePool public mockAavePool;
    Mock1InchAggregator public mock1InchAggregator;
    FlashLoanLiquidator public flashLoanLiquidator;

    function test_flashloan_liquidator_can_liquidate_and_withdraw() public {
        // Initialize mock contracts
        mockAavePool = new MockAavePool();
        mock1InchAggregator = new Mock1InchAggregator(address(priceFeed));

        // Fund the mock aggregator and pool with WETH and USDC
        _mint(address(weth), address(mock1InchAggregator), 100000e18);
        _mint(address(usdc), address(mock1InchAggregator), 10000000000000e18);
        _mint(address(weth), address(mockAavePool), 100000e18);
        _mint(address(usdc), address(mockAavePool), 1000000e6);


        // Initialize the FlashLoanLiquidator contract
        flashLoanLiquidator = new FlashLoanLiquidator(
            address(mockAavePool),
            address(size),
            address(mock1InchAggregator)
        );

        // Set the FlashLoanLiquidator contract as the keeper
        _setKeeperRole(address(flashLoanLiquidator));

        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 365 days);
        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        uint256 faceValue = debtPosition.faceValue;
        uint256 repayFee = debtPosition.repayFee;
        uint256 debt = faceValue + repayFee + size.feeConfig().overdueLiquidatorReward;

        _setPrice(0.31e18);

        uint256 repayFeeCollateral = size.debtTokenAmountToCollateralTokenAmount(repayFee);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        // _mint(address(usdc), address(flashLoanLiquidator), faceValue);
        // _approve(address(flashLoanLiquidator), address(usdc), address(size), faceValue);

        Vars memory _before = _state();
        uint256 beforeLiquidatorUSDC = usdc.balanceOf(liquidator);

        // Call the liquidatePositionWithFlashLoan function
        vm.prank(liquidator);
        flashLoanLiquidator.liquidatePositionWithFlashLoan(
            debtPositionId,
            0, // minimumCollateralProfit
            address(weth), // collateralToken
            address(usdc), // flashLoanAsset
            faceValue, // flashLoanAmount
            liquidator // The receiver of the liquidation proceeds
        );

        Vars memory _after = _state();
        uint256 afterLiquidatorUSDC = usdc.balanceOf(liquidator);

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - debt, 0);
        assertEq(_after.liquidator.borrowATokenBalance, _before.liquidator.borrowATokenBalance, 0);
        assertEq(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance, 0);
        assertGt(
            _after.feeRecipient.collateralTokenBalance,
            _before.feeRecipient.collateralTokenBalance + repayFeeCollateral,
            "feeRecipient has repayFee and liquidation split"
        );
        assertGt(afterLiquidatorUSDC, beforeLiquidatorUSDC, "Liquidator should have more USDC after liquidation");
    }
}