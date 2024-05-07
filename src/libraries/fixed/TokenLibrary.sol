// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";

/// @title TokenLibrary
/// @notice Contains functions for interacting with the underlying tokens
/// @dev Mints and burns 1:1 underlying tokens
library TokenLibrary {
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

    function depositUnderlyingBorrowToken(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata underlyingBorrowToken = IERC20Metadata(state.data.underlyingBorrowToken);
        underlyingBorrowToken.safeTransferFrom(from, address(this), amount);
        underlyingBorrowToken.forceApprove(address(state.data.borrowAToken), amount);
        state.data.borrowAToken.mint(to, amount);
    }

    function withdrawUnderlyingBorrowToken(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata underlyingBorrowToken = IERC20Metadata(state.data.underlyingBorrowToken);
        state.data.borrowAToken.burn(from, amount);
        underlyingBorrowToken.safeTransfer(to, amount);
    }
}
