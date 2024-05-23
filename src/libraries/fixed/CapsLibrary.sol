// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title CapsLibrary
/// @notice Contains functions for validating the cap of minted protocol-controlled tokens
library CapsLibrary {
    function validateBorrowATokenIncreaseLteDebtTokenDecrease(
        State storage state,
        uint256 borrowATokenSupplyBefore,
        uint256 debtTokenSupplyBefore,
        uint256 borrowATokenSupplyAfter,
        uint256 debtTokenSupplyAfter
    ) external view {
        // If the supply is above the cap
        if (borrowATokenSupplyAfter > state.riskConfig.borrowATokenCap) {
            uint256 borrowATokenSupplyIncrease = borrowATokenSupplyAfter > borrowATokenSupplyBefore
                ? borrowATokenSupplyAfter - borrowATokenSupplyBefore
                : 0;
            uint256 debtATokenSupplyDecrease =
                debtTokenSupplyBefore > debtTokenSupplyAfter ? debtTokenSupplyBefore - debtTokenSupplyAfter : 0;

            // and the supply increase is greater than the debt reduction
            if (borrowATokenSupplyIncrease > debtATokenSupplyDecrease) {
                // revert
                revert Errors.BORROW_ATOKEN_INCREASE_EXCEEDS_DEBT_TOKEN_DECREASE(
                    borrowATokenSupplyIncrease, debtATokenSupplyDecrease
                );
            }
            // otherwise, it means the debt reduction was greater than the inflow of cash: do not revert
        }
        // otherwise, the supply is below the cap: do not revert
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

    function validateVariablePoolHasEnoughLiquidity(State storage state, uint256 amount) public view {
        uint256 liquidity = state.data.underlyingBorrowToken.balanceOf(address(state.data.variablePool));
        if (liquidity < amount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY(liquidity, amount);
        }
    }
}
