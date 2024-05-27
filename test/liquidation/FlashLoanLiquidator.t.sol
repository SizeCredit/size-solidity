// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {FlashLoanLiquidator, SwapParams, SwapMethod, ReplacementParams} from "@src/periphery/FlashLoanLiquidation.sol";
import {Mock1InchAggregator} from "@test/mocks/Mock1InchAggregator.sol";
import {MockAavePool} from "@test/mocks/MockAavePool.sol";

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

    function test_flashloan_liquidator_liquidate_and_swap_1inch_withdraw() public {
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
            address(mock1InchAggregator),
            address(1), // placeholder for the unoswap router
            address(1), // placeholder for the uniswapv2 aggregator
            address(weth),
            address(usdc)
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
        uint256 debtPositionId = _sellCreditMarket(bob, alice, amount, block.timestamp + 365 days, false);
        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        // uint256 faceValue = debtPosition.faceValue;
        // uint256 repayFee = debtPosition.repayFee;
        // uint256 debt = faceValue + repayFee + size.feeConfig().overdueLiquidatorReward;
        uint256 debt = debtPosition.faceValue;

        _setPrice(0.2e18);

        // uint256 repayFeeCollateral = size.debtTokenAmountToCollateralTokenAmount(repayFee);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        // _mint(address(usdc), address(flashLoanLiquidator), faceValue);
        // _approve(address(flashLoanLiquidator), address(usdc), address(size), faceValue);

        Vars memory _before = _state();
        uint256 beforeLiquidatorUSDC = usdc.balanceOf(liquidator);

        // Create SwapParams for a 1inch swap
        SwapParams memory swapParams = SwapParams({
            method: SwapMethod.OneInch,
            data: abi.encode("") // Data is not used in the mock
        });

        // Create ReplacementParams, not used since useReplacement is false
        ReplacementParams memory replacementParams = ReplacementParams({
            minAPR: 0, // Example value, not used in this test
            deadline: block.timestamp + 1 days, // Example value, not used in this test
            replacementBorrower: address(0)
        });

        // Call the liquidatePositionWithFlashLoan function
        vm.prank(liquidator);
        flashLoanLiquidator.liquidatePositionWithFlashLoan(
            false, // useReplacement
            replacementParams, // Replacement parameters, not used here
            debtPositionId,
            0, // minimumCollateralProfit
            swapParams // Pass the swapParams
        );

        Vars memory _after = _state();
        uint256 afterLiquidatorUSDC = usdc.balanceOf(liquidator);

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - debt, 0);
        assertEq(_after.liquidator.borrowATokenBalance, _before.liquidator.borrowATokenBalance, 0);
        assertEq(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance, 0);
        assertGt(
            _after.feeRecipient.collateralTokenBalance,
            _before.feeRecipient.collateralTokenBalance,
            "feeRecipient has repayFee and liquidation split"
        );
        assertGt(afterLiquidatorUSDC, beforeLiquidatorUSDC, "Liquidator should have more USDC after liquidation");
    }

    function test_flashloan_liquidator_liquidate_with_replacement() public {
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
            address(mock1InchAggregator),
            address(1), // placeholder for the unoswap router
            address(1), // placeholder for the uniswapv2 aggregator
            address(weth),
            address(usdc)
        );

        // Set the FlashLoanLiquidator contract as the keeper
        _setKeeperRole(address(flashLoanLiquidator));

        // Setup borrowers and loans
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 amount = 15e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, amount, block.timestamp + 365 days, false);
        _setPrice(0.2e18); // Set a price that makes the position undercollateralized

        // Setup replacement borrower
        _deposit(candy, weth, 400e18);
        _deposit(candy, usdc, 1000e6);
        _borrowAsLimitOrder(candy, 0.03e18, block.timestamp + 365 days); // Valid borrow offer

        // Create SwapParams for a 1inch swap
        SwapParams memory swapParams = SwapParams({
            method: SwapMethod.OneInch,
            data: abi.encode("") // Data is not used in the mock
        });

        // Create ReplacementParams
        ReplacementParams memory replacementParams =
            ReplacementParams({minAPR: 0.03e18, deadline: block.timestamp + 1 days, replacementBorrower: candy});

        // Call the liquidatePositionWithFlashLoan function with replacement
        vm.prank(liquidator);
        flashLoanLiquidator.liquidatePositionWithFlashLoan(
            true, // useReplacement
            replacementParams,
            debtPositionId,
            0, // minimumCollateralProfit
            swapParams
        );

        // Assertions to verify the state after liquidation
        assertTrue(size.isDebtPositionLiquidatable(debtPositionId) == false, "Debt position should not be liquidatable");
        assertEq(size.getDebtPosition(debtPositionId).borrower, candy, "Debt position should be transferred to candy");
        assertGt(usdc.balanceOf(liquidator), 0, "Liquidator should have received some USDC as profit");
    }
}
