// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/periphery/FlashLoanLiquidation.sol";
import "./mocks/Mock1InchAggregator.sol";
import "./mocks/MockAavePool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FlashLoanLiquidatorTest is Test {
    FlashLoanLiquidator liquidator;
    Mock1InchAggregator mockAggregator;
    MockAavePool mockAavePool;
    IERC20 mockToken;

    address sizeLendingContract = address(0x123);
    address flashLoanAsset = address(0x456);
    address collateralToken = address(0x789);
    address liquidatorAddress = address(0xabc);

    function setUp() public {
        mockAggregator = new Mock1InchAggregator();
        mockAavePool = new MockAavePool();
        liquidator = new FlashLoanLiquidator(address(mockAavePool), sizeLendingContract, address(mockAggregator));
    }

    function testLiquidatePositionWithFlashLoan() public {
        uint256 debtPositionId = 1;
        uint256 minimumCollateralProfit = 100;
        uint256 flashLoanAmount = 1000;

        liquidator.liquidatePositionWithFlashLoan(
            debtPositionId,
            minimumCollateralProfit,
            collateralToken,
            flashLoanAsset,
            flashLoanAmount,
            liquidatorAddress
        );

        // TODO Add assertions to verify expected behavior
    }

    function testExecuteOperation() public {
        address[] memory assets = new address[](1);
        assets[0] = flashLoanAsset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;

        uint256[] memory premiums = new uint256[](1);
        premiums[0] = 10;

        bytes memory params = abi.encode(1, 100, liquidatorAddress, collateralToken);

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

