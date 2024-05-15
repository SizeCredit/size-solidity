// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/periphery/FlashLoanLiquidation.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {Pool} from "aave-v3-core/contracts/protocol/pool/Pool.sol";
import {Mock1InchAggregator} from "./mocks/Mock1InchAggregator.sol";

contract FlashLoanLiquidatorTest is Test {
    FlashLoanLiquidator liquidator;
    Mock1InchAggregator mockAggregator;
    PoolAddressesProvider poolAddressesProvider;
    Pool aavePool;
    IERC20 mockToken;

    address sizeLendingContract = address(0x123);
    address flashLoanAsset = address(0x456);
    address collateralToken = address(0x789);
    address liquidatorAddress = address(0xabc);

    function setUp() public {
        // Deploy the Aave PoolAddressesProvider and Pool
        poolAddressesProvider = new PoolAddressesProvider();
        aavePool = new Pool(address(poolAddressesProvider));

        // Set the pool in the PoolAddressesProvider
        poolAddressesProvider.setPoolImpl(address(aavePool));

        // Deploy the Mock1InchAggregator
        mockAggregator = new Mock1InchAggregator();

        // Deploy the FlashLoanLiquidator
        liquidator = new FlashLoanLiquidator(address(poolAddressesProvider), sizeLendingContract, address(mockAggregator));

        // Fund the Aave pool with liquidity
        mockToken = IERC20(flashLoanAsset);
        deal(address(mockToken), address(aavePool), 1000000 * 10**18); // Fund with 1,000,000 tokens
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

        // Add assertions to verify the expected behavior
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

        // Add more assertions to verify the expected behavior
    }
}