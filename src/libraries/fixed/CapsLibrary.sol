// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title CapsLibrary
/// @notice Contains functions for validating the cap of minted protocol-controlled tokens
library CapsLibrary {
    function validateCollateralTokenCap(State storage state) external view {
        if (state.data.collateralToken.totalSupply() > state.riskConfig.collateralTokenCap) {
            revert Errors.COLLATERAL_TOKEN_CAP_EXCEEDED(
                state.riskConfig.collateralTokenCap, state.data.collateralToken.totalSupply()
            );
        }
    }

    function validateBorrowATokenCap(State storage state) external view {
        if (state.data.borrowAToken.balanceOf(address(this)) > state.riskConfig.borrowATokenCap) {
            revert Errors.BORROW_ATOKEN_CAP_EXCEEDED(
                state.riskConfig.borrowATokenCap, state.data.borrowAToken.balanceOf(address(this))
            );
        }
    }

    function validateDebtTokenCap(State storage state) external view {
        if (state.data.debtToken.totalSupply() > state.riskConfig.debtTokenCap) {
            revert Errors.DEBT_TOKEN_CAP_EXCEEDED(state.riskConfig.debtTokenCap, state.data.debtToken.totalSupply());
        }
    }

    function validateVariablePoolHasEnoughLiquidity(State storage state, uint256 amount) public view {
        uint256 liquidity = state.data.underlyingBorrowToken.balanceOf(address(state.data.variablePool));
        if (liquidity < amount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY(liquidity, amount);
        }
    }
}
