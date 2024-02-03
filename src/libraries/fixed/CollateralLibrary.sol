// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";

library CollateralLibrary {
    using SafeERC20 for IERC20Metadata;

    function depositCollateralToken(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata collateralAsset = IERC20Metadata(state._general.collateralAsset);
        collateralAsset.transferFrom(from, address(this), amount);
        state._fixed.collateralToken.mint(to, amount);
    }

    function withdrawCollateralToken(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata collateralAsset = IERC20Metadata(state._general.collateralAsset);
        state._fixed.collateralToken.burn(from, amount);
        collateralAsset.safeTransfer(to, amount);
    }
}
