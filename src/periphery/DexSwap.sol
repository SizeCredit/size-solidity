// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./interfaces/I1InchAggregator.sol";
// import "./interfaces/IUnoswapRouter.sol";
// import "./interfaces/IUniswapV2Router02.sol";

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

contract DexSwap {
    I1InchAggregator public oneInchAggregator;
    IUnoswapRouter public unoswapRouter;
    IUniswapV2Router02 public uniswapRouter;
    address public collateralToken;
    address public debtToken;

    constructor(address _oneInchAggregator, address _unoswapRouter, address _uniswapRouter, address _collateralToken, address _debtToken) {
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
            return swapCollateral1Inch(swapParams.data);
        } else if (swapParams.method == SwapMethod.Unoswap) {
            address pool = abi.decode(swapParams.data, (address));
            return swapCollateralUnoswap(pool);
        } else if (swapParams.method == SwapMethod.Uniswap) {
            address[] memory path = abi.decode(swapParams.data, (address[]));
            return swapCollateralUniswap(path);
        } else {
            revert("Invalid swap method");
        }
    }

    function swapCollateral1Inch(bytes memory data) internal returns (uint256) {
        uint256 swappedAmount = oneInchAggregator.swap(
            collateralToken,
            debtToken,
            IERC20(collateralToken).balanceOf(address(this)),
            1, // Minimum return amount
            data
        );
        return swappedAmount;
    }

    function swapCollateralUniswap(address[] memory tokenPaths) internal returns (uint256) {
        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            IERC20(collateralToken).balanceOf(address(this)),
            1, // Minimum return amount
            tokenPaths,
            address(this),
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    function swapCollateralUnoswap(address pool) internal returns (uint256) {
        uint256 returnAmount = unoswapRouter.unoswapTo(
            address(this),
            collateralToken,
            IERC20(collateralToken).balanceOf(address(this)),
            1, // Minimum return amount
            pool
        );

        return returnAmount;
    }
}