// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";

/// @title CollateralLibrary
/// @notice Contains functions for interacting with the underlying collateral token (e.g. WETH)
/// @dev Mints and burns 1:1 the collateral token (e.g. szETH)
library CollateralLibrary {
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
}
