// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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
        (uint256 debtPositionId, uint256 minimumCollateralProfit, address liquidator, address collateralToken) = abi.decode(params, (uint256, uint256, address, address));

        // Liquidate the debt position and withdraw all assets
        liquidateDebtPosition(collateralToken, assets[0], amounts[0], debtPositionId, minimumCollateralProfit);

        // Swap the collateral tokens for the debt tokens and withdraw everything
        swapCollateral(collateralToken, assets[0]);

        // Settle the debt tokens and flash loan
        settleFlashLoan(assets, amounts, premiums, liquidator);

        return true;
    }

    function liquidateDebtPosition(
        address collateralToken,
        address debtToken,
        uint256 debtAmount,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit
    ) internal {
        // Approve and deposit USDC to repay the borrower's debt
        IERC20(debtToken).approve(address(sizeLendingContract), debtAmount);
        sizeLendingContract.deposit(DepositParams({
            token: debtToken,
            amount: debtAmount,
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
            token: debtToken,
            amount: type(uint256).max,
            to: address(this)
        }));
        sizeLendingContract.withdraw(WithdrawParams({
            token: collateralToken,
            amount: type(uint256).max,
            to: address(this)
        }));
    }

    function swapCollateral(
        address collateralToken,
        address debtToken
    ) internal returns (uint256) {
        // Approve the aggregator to spend the collateral tokens
        IERC20(collateralToken).approve(address(aggregator), type(uint256).max);

        // Swap the collateral tokens for the debt tokens using the aggregator
        uint256 swappedAmount = aggregator.swap(
            collateralToken,
            debtToken,
            IERC20(collateralToken).balanceOf(address(this)),
            1, // Minimum return amount
            ""
        );

        return swappedAmount;
    }

    function settleFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address liquidator
    ) internal {
        uint256 totalDebt = amounts[0] + premiums[0];
        uint256 balance = IERC20(assets[0]).balanceOf(address(this));

        // Ensure the balance is sufficient to cover the amounts and premiums 
        require(balance >= totalDebt, "Insufficient balance to repay flash loan"); 

        // Calculate the amount to transfer to the liquidator
        uint256 amountToLiquidator = balance - totalDebt;

        // Transfer the remaining debt tokens to the liquidator
        IERC20(assets[0]).transfer(liquidator, amountToLiquidator);

        // Approve the Pool contract to pull the owed amount
        IERC20(assets[0]).approve(address(POOL), amounts[0] + premiums[0]);
    }

    function liquidatePositionWithFlashLoan(
        uint256 debtPositionId, // Debt position ID being liquidated
        uint256 minimumCollateralProfit, 
        address collateralToken, 
        address flashLoanAsset, // Debt token
        uint256 flashLoanAmount, // Amount of debt token to flash loan
        address liquidator // The receiver of the liquidation proceeds
    ) external {
        bytes memory params = abi.encode(debtPositionId, minimumCollateralProfit, liquidator, collateralToken);

        address[] memory assets = new address[](1);
        assets[0] = flashLoanAsset; // The debt token (e.g. USDC)

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