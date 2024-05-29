// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {I1InchAggregator} from "@src/periphery/interfaces/dex/I1InchAggregator.sol";

import {IUniswapV2Router02} from "@src/periphery/interfaces/dex/IUniswapV2Router02.sol";
import {IUnoswapRouter} from "@src/periphery/interfaces/dex/IUnoswapRouter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

enum SwapMethod {
    OneInch,
    Unoswap,
    Uniswap
}

struct SwapParams {
    SwapMethod method;
    bytes data; // Encoded data for the specific swap method
    uint256 deadline; // Deadline for the swap to occur
    uint256 minimumReturnAmount; // Minimum return amount from the swap
}

contract DexSwap {
    I1InchAggregator public oneInchAggregator;
    IUnoswapRouter public unoswapRouter;
    IUniswapV2Router02 public uniswapRouter;
    address public collateralToken;
    address public debtToken;

    constructor(
        address _oneInchAggregator,
        address _unoswapRouter,
        address _uniswapRouter,
        address _collateralToken,
        address _debtToken
    ) {
        oneInchAggregator = I1InchAggregator(_oneInchAggregator);
        unoswapRouter = IUnoswapRouter(_unoswapRouter);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        collateralToken = _collateralToken;
        debtToken = _debtToken;

        // Approve the dexs to spend the collateral tokens
        IERC20(collateralToken).approve(address(oneInchAggregator), type(uint256).max);
        IERC20(collateralToken).approve(address(unoswapRouter), type(uint256).max);
        IERC20(collateralToken).approve(address(uniswapRouter), type(uint256).max);
    }

    function swapCollateral(SwapParams memory swapParams) internal returns (uint256) {
        if (swapParams.method == SwapMethod.OneInch) {
            return swapCollateral1Inch(swapParams.data, swapParams.minimumReturnAmount);
        } else if (swapParams.method == SwapMethod.Unoswap) {
            address pool = abi.decode(swapParams.data, (address));
            return swapCollateralUnoswap(pool, swapParams.minimumReturnAmount);
        } else if (swapParams.method == SwapMethod.Uniswap) {
            address[] memory path = abi.decode(swapParams.data, (address[]));
            return swapCollateralUniswap(path, swapParams.deadline, swapParams.minimumReturnAmount);
        } else {
            revert("Invalid swap method");
        }
    }

    function swapCollateral1Inch(bytes memory data, uint256 minimumReturnAmount) internal returns (uint256) {
        uint256 swappedAmount = oneInchAggregator.swap(
            collateralToken, debtToken, IERC20(collateralToken).balanceOf(address(this)), minimumReturnAmount, data
        );
        return swappedAmount;
    }

    function swapCollateralUniswap(address[] memory tokenPaths, uint256 deadline, uint256 minimumReturnAmount)
        internal
        returns (uint256)
    {
        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            IERC20(collateralToken).balanceOf(address(this)), minimumReturnAmount, tokenPaths, address(this), deadline
        );
        return amounts[amounts.length - 1];
    }

    function swapCollateralUnoswap(address pool, uint256 minimumReturnAmount) internal returns (uint256) {
        uint256 returnAmount = unoswapRouter.unoswapTo(
            address(this), collateralToken, IERC20(collateralToken).balanceOf(address(this)), minimumReturnAmount, pool
        );

        return returnAmount;
    }
}
