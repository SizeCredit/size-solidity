// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {FlashLoanLiquidator, SwapParams, SwapMethod, ReplacementParams} from "@src/periphery/FlashLoanLiquidation.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

contract ForkTest is BaseTest, BaseScript {
    address public owner;
    IAToken public aToken;
    FlashLoanLiquidator public flashLoanLiquidator;

    function setUp() public override {
        _labels();
        vm.createSelectFork("sepolia");
        vm.rollFork(5395350);
        (size, variablePoolBorrowRateFeed, priceFeed, variablePool, usdc, weth, owner) = importDeployments();
        aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);

        address uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // there is actually no deployment of this on sepolia :/

        // Deploy the FlashLoanLiquidator contract
        flashLoanLiquidator = new FlashLoanLiquidator(
            address(variablePool),
            address(size),
            address(0), // placeholder for the 1inch aggregator
            address(0), // placeholder for the unoswap router
            address(uniswapRouter), // Uniswap V2 Router address
            address(weth),
            address(usdc)
        );

        // Set the FlashLoanLiquidator contract as the keeper
        _setKeeperRole(address(flashLoanLiquidator));
    }

    function testFork_flashloan_liquidator_liquidate_and_swap_uniswap() public {
        // Set up initial state
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

        Vars memory _before = _state();
        uint256 beforeLiquidatorUSDC = usdc.balanceOf(liquidator);

        // Create SwapParams for a Uniswap swap
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);
        SwapParams memory swapParams = SwapParams({
            method: SwapMethod.Uniswap,
            data: abi.encode(path)
        });

        ReplacementParams memory replacementParams; // replacement params not used here

        // Call the liquidatePositionWithFlashLoan function
        vm.prank(liquidator);
        flashLoanLiquidator.liquidatePositionWithFlashLoan(
            false, // useReplacement
            replacementParams,
            debtPositionId,
            0, // minimumCollateralProfit
            swapParams // Pass the swapParams
        );

        Vars memory _after = _state();
        uint256 afterLiquidatorUSDC = usdc.balanceOf(liquidator);

        // Verify the results
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