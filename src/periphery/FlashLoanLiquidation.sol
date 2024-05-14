// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";
import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";

interface I1InchAggregator {
    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata data
    ) external payable returns (uint256 returnAmount);
}

contract FlashLoanLiquidator is FlashLoanReceiverBase {
    ISize public sizeLendingContract;
    I1InchAggregator public aggregator;

    constructor(address _addressProvider, address _sizeLendingContractAddress, address _aggregator) FlashLoanReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        sizeLendingContract = ISize(_sizeLendingContractAddress);
        aggregator = I1InchAggregator(_aggregator);
        POOL = IPool(IPoolAddressesProvider(_addressProvider).getPool());
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL));
        require(initiator == address(this));

        // Decode the params to get the necessary information
        (uint256 debtPositionId, uint256 minimumCollateralProfit, address liquidator) = abi.decode(params, (uint256, uint256, address));

        // Approve and deposit USDC to repay the borrower's debt
        IERC20(assets[0]).approve(address(sizeLendingContract), amounts[0]);
        sizeLendingContract.deposit(DepositParams({
            token: assets[0],
            amount: amounts[0],
            to: address(this)
        }));

        // Create the LiquidateParams struct
        LiquidateParams memory liquidateParams = LiquidateParams({
            debtPositionId: debtPositionId,
            minimumCollateralProfit: minimumCollateralProfit
        });

        // Perform the liquidation using the deposited funds
        sizeLendingContract.liquidate(liquidateParams);

        // Withdraw the collateral and debt tokens
        sizeLendingContract.withdraw(WithdrawParams({
            token: assets[0],
            amount: type(uint256).max,
            to: address(this)
        }));
        sizeLendingContract.withdraw(WithdrawParams({
            token: assets[1],
            amount: type(uint256).max,
            to: address(this)
        }));

        // Swap the collateral tokens for the debt tokens using the aggregator
        IERC20(assets[0]).approve(address(aggregator), type(uint256).max);
        uint256 swappedAmount = aggregator.swap(
            assets[1], // Assuming assets[1] is the collateral token (e.g. WETH)
            assets[0], // Assuming assets[0] is the debt token (e.g. USDC)
            IERC20(assets[1]).balanceOf(address(this)),
            1, // Minimum return amount
            ""
        );

        // Transfer the swapped debt tokens to the liquidator
        IERC20(assets[1]).transfer(liquidator, swappedAmount);

        // Approve the Pool contract to pull the owed amount
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).approve(address(POOL), amounts[i] + premiums[i]);
        }

        return true;
    }

    function liquidatePositionWithFlashLoan(
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        address flashLoanAsset,
        uint256 flashLoanAmount,
        address liquidator
    ) external {
        bytes memory params = abi.encode(debtPositionId, minimumCollateralProfit, liquidator);

        address[] memory assets = new address[](2);
        assets[0] = flashLoanAsset; // The debt token (e.g. USDC)
        assets[1] = address(0); // Placeholder for the collateral token (e.g. WETH)

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        POOL.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }
}