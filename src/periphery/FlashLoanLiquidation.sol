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

contract FlashLoanLiquidator is FlashLoanReceiverBase {
    ISize public sizeLendingContract;

    constructor(address _addressProvider, address _sizeLendingContractAddress) FlashLoanReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        sizeLendingContract = ISize(_sizeLendingContractAddress);
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

        // Withdraw the collateral and transfer to the liquidator
        sizeLendingContract.withdraw(WithdrawParams({
            token: assets[0],
            amount: type(uint256).max,
            to: liquidator
        }));

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
        address liquidator // the receiver of the liquidation proceeds, parameterised to allow anyone to use this contract
    ) external {
        bytes memory params = abi.encode(debtPositionId, minimumCollateralProfit, liquidator);

        address[] memory assets = new address[](1);
        assets[0] = flashLoanAsset;

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