// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";

import {FlashLoanReceiverBase} from "@aave/flashloan/base/FlashLoanReceiverBase.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";
import {DexSwap, SwapParams} from "@src/periphery/DexSwap.sol";

struct ReplacementParams {
    uint256 minAPR;
    uint256 deadline;
    address replacementBorrower;
}

struct OperationParams {
    uint256 debtPositionId;
    uint256 minimumCollateralProfit;
    address liquidator;
    SwapParams swapParams;
    bool useReplacement;
    ReplacementParams replacementParams;
}

contract FlashLoanLiquidator is FlashLoanReceiverBase, DexSwap {
    ISize public immutable sizeLendingContract;

    constructor(
        address _addressProvider,
        address _sizeLendingContractAddress,
        address _1inchAggregator,
        address _unoswapRouter,
        address _uniswapRouter,
        address _collateralToken,
        address _debtToken
    )
        FlashLoanReceiverBase(IPoolAddressesProvider(_addressProvider))
        DexSwap(_1inchAggregator, _unoswapRouter, _uniswapRouter, _collateralToken, _debtToken)
    {
        if (_sizeLendingContractAddress == address(0) || _addressProvider == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        POOL = IPool(IPoolAddressesProvider(_addressProvider).getPool());
        sizeLendingContract = ISize(_sizeLendingContractAddress);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Can only be called by Aave pool");
        require(initiator == address(this), "Can only be initiated by this contract");

        OperationParams memory opParams = abi.decode(params, (OperationParams));

        if (opParams.useReplacement) {
            liquidateDebtPositionWithReplacement(
                amounts[0], opParams.debtPositionId, opParams.minimumCollateralProfit, opParams.replacementParams
            );
        } else {
            liquidateDebtPosition(amounts[0], opParams.debtPositionId, opParams.minimumCollateralProfit);
        }

        swapCollateral(opParams.swapParams);
        settleFlashLoan(assets, amounts, premiums, opParams.liquidator);

        return true;
    }

    function liquidateDebtPositionWithReplacement(
        uint256 debtAmount,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        ReplacementParams memory replacementParams
    ) internal {
        // Approve USDC to repay the borrower's debt
        IERC20(debtToken).approve(address(sizeLendingContract), debtAmount);

        // Encode Deposit
        bytes memory depositCall = abi.encodeWithSelector(
            ISize.deposit.selector, DepositParams({token: debtToken, amount: debtAmount, to: address(this)})
        );

        // Encode Liquidate with Replacement
        bytes memory liquidateCall = abi.encodeWithSelector(
            ISize.liquidateWithReplacement.selector,
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: replacementParams.replacementBorrower,
                minimumCollateralProfit: minimumCollateralProfit,
                deadline: replacementParams.deadline,
                minAPR: replacementParams.minAPR
            })
        );

        // Encode Withdraw
        bytes memory withdrawCall = abi.encodeWithSelector(
            ISize.withdraw.selector,
            WithdrawParams({token: collateralToken, amount: type(uint256).max, to: address(this)})
        );

        // Multicall
        bytes[] memory calls = new bytes[](3);
        calls[0] = depositCall;
        calls[1] = liquidateCall;
        calls[2] = withdrawCall;

        sizeLendingContract.multicall(calls);
    }

    function liquidateDebtPosition(uint256 debtAmount, uint256 debtPositionId, uint256 minimumCollateralProfit)
        internal
    {
        // Approve USDC to repay the borrower's debt
        IERC20(debtToken).approve(address(sizeLendingContract), debtAmount);

        // Encode Deposit
        bytes memory depositCall = abi.encodeWithSelector(
            ISize.deposit.selector, DepositParams({token: debtToken, amount: debtAmount, to: address(this)})
        );

        // Encode Liquidate
        bytes memory liquidateCall = abi.encodeWithSelector(
            ISize.liquidate.selector,
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );

        // Encode Withdraw
        bytes memory withdrawCall = abi.encodeWithSelector(
            ISize.withdraw.selector,
            WithdrawParams({token: collateralToken, amount: type(uint256).max, to: address(this)})
        );

        // Multicall
        bytes[] memory calls = new bytes[](3);
        calls[0] = depositCall;
        calls[1] = liquidateCall;
        calls[2] = withdrawCall;

        sizeLendingContract.multicall(calls);
    }

    function settleFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address liquidator
    ) internal {
        uint256 totalDebt = amounts[0] + premiums[0];
        uint256 balance = IERC20(assets[0]).balanceOf(address(this));

        require(balance >= totalDebt, "Insufficient balance to repay flash loan");

        uint256 amountToLiquidator = balance - totalDebt;
        IERC20(assets[0]).transfer(liquidator, amountToLiquidator);

        // Approve the Pool contract to pull the owed amount
        IERC20(assets[0]).approve(address(POOL), amounts[0] + premiums[0]);
    }

    function liquidatePositionWithFlashLoan(
        bool useReplacement,
        ReplacementParams memory replacementParams,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        SwapParams memory swapParams
    ) external {
        OperationParams memory opParams = OperationParams({
            debtPositionId: debtPositionId,
            minimumCollateralProfit: minimumCollateralProfit,
            liquidator: msg.sender,
            swapParams: swapParams,
            useReplacement: useReplacement,
            replacementParams: replacementParams
        });

        bytes memory params = abi.encode(opParams);

        address[] memory assets = new address[](1);
        assets[0] = debtToken;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = sizeLendingContract.getDebtPosition(debtPositionId).futureValue;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        POOL.flashLoan(address(this), assets, amounts, modes, address(this), params, 0);
    }
}
