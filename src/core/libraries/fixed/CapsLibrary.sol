// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/core/SizeStorage.sol";
import {Errors} from "@src/core/libraries/Errors.sol";

/// @title CapsLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
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

    function validateVariablePoolHasEnoughLiquidity(State storage state, uint256 amount) public view {
        uint256 liquidity = state.data.underlyingBorrowToken.balanceOf(address(state.data.variablePool));
        if (liquidity < amount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY(liquidity, amount);
        }
    }
}
