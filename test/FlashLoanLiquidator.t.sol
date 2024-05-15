// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/periphery/FlashLoanLiquidation.sol";
import "./mocks/Mock1InchAggregator.sol";
import "./mocks/MockAavePool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract FlashLoanLiquidatorTest is BaseTest {
    FlashLoanLiquidator liquidator;
    Mock1InchAggregator mockAggregator;
    MockAavePool mockAavePool;
    ISize size;

    address flashLoanAsset = address(0x456);
    address collateralToken = address(0x789);
    address liquidatorAddress = address(0xabc);

    function setUp() public override {
        super.setUp();

        mockAggregator = new Mock1InchAggregator();
        mockAavePool = new MockAavePool();
        liquidator = new FlashLoanLiquidator(address(mockAavePool), address(size), address(mockAggregator));

        // Set up initial balances and approvals
        deal(address(usdc), alice, 1000e6);
        deal(address(usdc), bob, 1000e6);
        deal(address(weth), alice, 100e18);
        deal(address(weth), bob, 100e18);

        vm.startPrank(alice);
        IERC20(address(usdc)).approve(address(size), 1000e6);
        IERC20(address(weth)).approve(address(size), 100e18);
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(address(usdc)).approve(address(size), 1000e6);
        IERC20(address(weth)).approve(address(size), 100e18);
        vm.stopPrank();

        // Create borrower and lender positions
        vm.startPrank(alice);
        size.deposit(DepositParams({token: address(usdc), amount: 1000e6, to: alice}));
        size.deposit(DepositParams({token: address(weth), amount: 100e18, to: alice}));
        vm.stopPrank();

        vm.startPrank(bob);
        size.deposit(DepositParams({token: address(usdc), amount: 1000e6, to: bob}));
        size.deposit(DepositParams({token: address(weth), amount: 100e18, to: bob}));
        vm.stopPrank();

        // Create a debt position
        vm.startPrank(bob);
        uint256 debtPositionId = size.borrowAsMarketOrder(BorrowAsMarketOrderParams({
            lender: alice,
            amount: 1000e6,
            dueDate: block.timestamp + 365 days,
            exactAmountIn: true,
            receivableCreditPositionIds: new uint256[](0)
        }));
        vm.stopPrank();
    }

    function testLiquidatePositionWithFlashLoan() public {
        uint256 debtPositionId = 1;
        uint256 minimumCollateralProfit = 100;
        uint256 flashLoanAmount = 1000e6;

        liquidator.liquidatePositionWithFlashLoan(
            debtPositionId,
            minimumCollateralProfit,
            address(weth),
            address(usdc),
            flashLoanAmount,
            liquidatorAddress
        );

        // TODO Add assertions to verify expected behavior
    }

    function testExecuteOperation() public {
        address[] memory assets = new address[](1);
        assets[0] = address(usdc);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        uint256[] memory premiums = new uint256[](1);
        premiums[0] = 10e6;

        bytes memory params = abi.encode(1, 100, liquidatorAddress, address(weth));

        bool success = liquidator.executeOperation(
            assets,
            amounts,
            premiums,
            address(liquidator),
            params
        );

        assertTrue(success, "executeOperation should return true");

        // TODO Add assertions to verify expected behavior
    }
}