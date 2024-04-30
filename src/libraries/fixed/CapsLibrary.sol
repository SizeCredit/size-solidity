// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title CapsLibrary
/// @notice Contains functions for validating the cap of minted protocol-controlled tokens
library CapsLibrary {
    function validateBorrowATokenIncreaseLowerThanDebtTokenDecrease(
        State storage state,
        uint256 borrowATokenSupplyBefore,
        uint256 debtTokenSupplyBefore,
        uint256 borrowATokenSupplyAfter,
        uint256 debtTokenSupplyAfter
    ) external view {
        uint256 borrowATokenSupplyIncrease =
            borrowATokenSupplyAfter > borrowATokenSupplyBefore ? borrowATokenSupplyAfter - borrowATokenSupplyBefore : 0;
        uint256 debtATokenSupplyDecrease =
            debtTokenSupplyBefore > debtTokenSupplyAfter ? debtTokenSupplyBefore - debtTokenSupplyAfter : 0;

        // If the borrow aToken supply was already above the cap
        if (borrowATokenSupplyBefore > state.riskConfig.borrowATokenCap) {
            // and the increase is greater than the debt reduction
            if (borrowATokenSupplyIncrease > debtATokenSupplyDecrease) {
                // revert
                revert Errors.BORROW_ATOKEN_INCREASE_EXCEEDS_DEBT_TOKEN_DECREASE(
                    borrowATokenSupplyIncrease, debtATokenSupplyDecrease
                );
            }
            // otherwise, it means the debt reduction was greater than the inflow of cash: do not revert
        }
        // otherwise, the borrow aToken was previously below the cap: do not revert
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
