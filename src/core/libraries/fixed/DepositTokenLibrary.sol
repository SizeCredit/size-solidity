// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/core/SizeStorage.sol";

/// @title DepositTokenLibrary
/// @notice Contains functions for interacting with underlying tokens
/// @dev Mints and burns 1:1 Size deposit tokens in exchange for underlying tokens
library DepositTokenLibrary {
    using SafeERC20 for IERC20Metadata;

    function depositUnderlyingCollateralToken(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(state.data.underlyingCollateralToken);
        underlyingCollateralToken.safeTransferFrom(from, address(this), amount);
        state.data.collateralToken.mint(to, amount);
    }

    function withdrawUnderlyingCollateralToken(State storage state, address from, address to, uint256 amount)
        external
    {
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(state.data.underlyingCollateralToken);
        state.data.collateralToken.burn(from, amount);
        underlyingCollateralToken.safeTransfer(to, amount);
    }

    function depositUnderlyingBorrowTokenToVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        state.data.underlyingBorrowToken.safeTransferFrom(from, address(this), amount);

        IAToken aToken =
            IAToken(state.data.variablePool.getReserveData(address(state.data.underlyingBorrowToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        state.data.underlyingBorrowToken.forceApprove(address(state.data.variablePool), amount);
        state.data.variablePool.supply(address(state.data.underlyingBorrowToken), amount, address(this), 0);

        uint256 scaledAmount = aToken.scaledBalanceOf(address(this)) - scaledBalanceBefore;

        state.data.borrowAToken.mintScaled(to, scaledAmount);
    }

    function withdrawUnderlyingTokenFromVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        IAToken aToken =
            IAToken(state.data.variablePool.getReserveData(address(state.data.underlyingBorrowToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        state.data.variablePool.withdraw(address(state.data.underlyingBorrowToken), amount, to);

        uint256 scaledAmount = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));

        state.data.borrowAToken.burnScaled(from, scaledAmount);
    }
}
