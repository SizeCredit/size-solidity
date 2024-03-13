// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

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
        if (state.data.borrowAToken.totalSupply() > state.riskConfig.borrowATokenCap) {
            revert Errors.BORROW_ATOKEN_CAP_EXCEEDED(
                state.riskConfig.borrowATokenCap, state.data.borrowAToken.totalSupply()
            );
        }
    }

    function validateDebtTokenCap(State storage state) external view {
        if (state.data.debtToken.totalSupply() > state.riskConfig.debtTokenCap) {
            revert Errors.DEBT_TOKEN_CAP_EXCEEDED(state.riskConfig.debtTokenCap, state.data.debtToken.totalSupply());
        }
    }

    function validateVariablePoolHasEnoughLiquidity(State storage state) public view {
        uint256 redeemable = state.data.borrowAToken.totalSupply();
        uint256 liquidity = state.data.underlyingBorrowToken.balanceOf(address(state.data.variablePool));
        if (liquidity < redeemable) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY(liquidity, redeemable);
        }
    }
}
