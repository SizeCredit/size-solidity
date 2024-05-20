// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FlashLoanReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
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

interface IUnoswapRouter {
    function unoswapTo(
        address recipient,
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        address pool
    ) external payable returns (uint256 returnAmount);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

enum SwapMethod {
    OneInch,
    Unoswap,
    Uniswap
}

struct SwapParams {
    SwapMethod method;
    bytes data; // Encoded data for the specific swap method
}

struct ReplacementParams {
    uint256 minAPR;
    uint256 deadline;
    address replacementBorrower;
}

struct OperationParams {
    uint256 debtPositionId;
    uint256 minimumCollateralProfit;
    address liquidator;
    address collateralToken;
    SwapParams swapParams;
    bool useReplacement;
    ReplacementParams replacementParams;
}

contract FlashLoanLiquidator is FlashLoanReceiverBase {
    ISize public sizeLendingContract;
    I1InchAggregator public oneInchAggregator;
    IUnoswapRouter public unoswapRouter;
    IUniswapV2Router02 public uniswapRouter;

    constructor(
        address _addressProvider,
        address _sizeLendingContractAddress,
        address _1inchAggregator,
        address _unoswapRouter,
        address _uniswapRouter
    ) FlashLoanReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        POOL = IPool(IPoolAddressesProvider(_addressProvider).getPool());
        sizeLendingContract = ISize(_sizeLendingContractAddress);
        oneInchAggregator = I1InchAggregator(_1inchAggregator);
        unoswapRouter = IUnoswapRouter(_unoswapRouter);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Not Aave Pool");
        require(initiator == address(this), "Not Initiator");

        OperationParams memory opParams = abi.decode(params, (OperationParams));

        if (opParams.useReplacement) {
            liquidateDebtPositionWithReplacement(
                opParams.collateralToken,
                assets[0],
                amounts[0],
                opParams.debtPositionId,
                opParams.minimumCollateralProfit,
                opParams.replacementParams 
            );
        } else {
            liquidateDebtPosition(
                opParams.collateralToken,
                assets[0],
                amounts[0],
                opParams.debtPositionId,
                opParams.minimumCollateralProfit
            );
        }

        swapCollateral(opParams.collateralToken, assets[0], opParams.swapParams);
        settleFlashLoan(assets, amounts, premiums, opParams.liquidator);

        return true;
    }

    function liquidateDebtPositionWithReplacement(
        address collateralToken,
        address debtToken,
        uint256 debtAmount,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        ReplacementParams memory replacementParams
    ) internal {
        // Approve and deposit USDC to repay the borrower's debt
        IERC20(debtToken).approve(address(sizeLendingContract), debtAmount);
        sizeLendingContract.deposit(DepositParams({
            token: debtToken,
            amount: debtAmount,
            to: address(this)
        }));

        LiquidateWithReplacementParams memory params = LiquidateWithReplacementParams({
            debtPositionId: debtPositionId,
            borrower: replacementParams.replacementBorrower, // Use the specified replacement borrower
            minimumCollateralProfit: minimumCollateralProfit,
            deadline: replacementParams.deadline,
            minAPR: replacementParams.minAPR
        });
        sizeLendingContract.liquidateWithReplacement(params);

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
        address debtToken,
        SwapParams memory swapParams
    ) internal returns (uint256) {
        if (swapParams.method == SwapMethod.OneInch) {
            return swapCollateral1Inch(collateralToken, debtToken, swapParams.data);
        } else if (swapParams.method == SwapMethod.Unoswap) {
            address pool = abi.decode(swapParams.data, (address));
            return swapCollateralUnoswap(collateralToken, pool);
        } else if (swapParams.method == SwapMethod.Uniswap) {
            address[] memory path = abi.decode(swapParams.data, (address[]));
            return swapCollateralUniswap(collateralToken, path);
        } else {
            revert("Invalid swap method");
        }
    }

    function swapCollateral1Inch(
        address collateralToken,
        address debtToken,
        bytes memory data
    ) internal returns (uint256) {
        // Approve the 1InchAggregator to spend the collateral tokens
        IERC20(collateralToken).approve(address(oneInchAggregator), type(uint256).max);

        // Swap the collateral tokens for the debt tokens using the 1InchAggregator
        uint256 swappedAmount = oneInchAggregator.swap(
            collateralToken,
            debtToken,
            IERC20(collateralToken).balanceOf(address(this)),
            1, // Minimum return amount
            data
        );

        return swappedAmount;
    }

    function swapCollateralUniswap(
        address collateralToken,
        address[] memory tokenPaths
    ) internal returns (uint256) {
        // Approve the UniswapRouter to spend the collateral tokens
        IERC20(collateralToken).approve(address(uniswapRouter), type(uint256).max);

        // address[] memory path = new address[](2);
        // path[0] = collateralToken;
        // path[1] = debtToken;

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            IERC20(collateralToken).balanceOf(address(this)),
            1, // Minimum return amount
            tokenPaths,
            address(this),
            block.timestamp
        );

        return amounts[amounts.length - 1];
    }

    function swapCollateralUnoswap(
        address collateralToken,
        address pool
    ) internal returns (uint256) {
        // Approve the UnoswapRouter to spend the collateral tokens
        IERC20(collateralToken).approve(address(unoswapRouter), type(uint256).max);

        // Perform the swap using the unoswapTo function
        uint256 returnAmount = unoswapRouter.unoswapTo(
            address(this),
            collateralToken,
            IERC20(collateralToken).balanceOf(address(this)),
            1, // TODO consider calculating reasonable minimum return amount
            pool
        );

        return returnAmount;
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
        address asset,
        bool useReplacement,
        ReplacementParams memory replacementParams,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        address collateralToken,
        SwapParams memory swapParams
    ) external {
        OperationParams memory opParams = OperationParams({
            debtPositionId: debtPositionId,
            minimumCollateralProfit: minimumCollateralProfit,
            liquidator: msg.sender,
            collateralToken: collateralToken,
            swapParams: swapParams,
            useReplacement: useReplacement,
            replacementParams: replacementParams
        });

        bytes memory params = abi.encode(opParams);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = sizeLendingContract.getOverdueDebt(debtPositionId);
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