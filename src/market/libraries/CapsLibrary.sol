// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {State} from "@src/market/SizeStorage.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

/// @title CapsLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains functions for validating the cap of minted protocol-controlled tokens
library CapsLibrary {
    /// @notice Validate that the increase in borrow token supply is less than or equal to the decrease in debt token supply
    /// @dev Reverts if the debt increase is greater than the supply increase and the supply is above the cap
    /// @param state The state struct
    /// @param borrowTokenSupplyBefore The borrow token supply before the transaction
    /// @param debtTokenSupplyBefore The debt token supply before the transaction
    /// @param borrowTokenSupplyAfter The borrow token supply after the transaction
    /// @param debtTokenSupplyAfter The debt token supply after the transaction
    function validateBorrowTokenIncreaseLteDebtTokenDecrease(
        State storage state,
        uint256 borrowTokenSupplyBefore,
        uint256 debtTokenSupplyBefore,
        uint256 borrowTokenSupplyAfter,
        uint256 debtTokenSupplyAfter
    ) external view {
        // If the supply is above the cap
        if (borrowTokenSupplyAfter > state.riskConfig.borrowTokenCap) {
            uint256 borrowTokenSupplyIncrease =
                borrowTokenSupplyAfter > borrowTokenSupplyBefore ? borrowTokenSupplyAfter - borrowTokenSupplyBefore : 0;
            uint256 debtTokenSupplyDecrease =
                debtTokenSupplyBefore > debtTokenSupplyAfter ? debtTokenSupplyBefore - debtTokenSupplyAfter : 0;

            // and the supply increase is greater than the debt reduction
            if (borrowTokenSupplyIncrease > debtTokenSupplyDecrease) {
                // revert
                revert Errors.BORROW_TOKEN_INCREASE_EXCEEDS_DEBT_TOKEN_DECREASE(
                    borrowTokenSupplyIncrease, debtTokenSupplyDecrease
                );
            }
            // otherwise, it means the debt reduction was greater than the inflow of cash: do not revert
        }
        // otherwise, the supply is below the cap: do not revert
    }

    /// @notice Validate that the borrow aToken supply is less than or equal to the borrow aToken cap
    /// @dev Reverts if the borrow aToken supply is greater than the borrow aToken cap
    ///      Due to rounding, the borrow aToken supply may be slightly less than the actual AToken supply, which is acceptable.
    /// @param state The state struct
    function validateBorrowTokenCap(State storage state) external view {
        // TODO: this is not cheching against ALL vaults
        if (state.data.borrowTokenVault.totalSupply() > state.riskConfig.borrowTokenCap) {
            revert Errors.BORROW_TOKEN_CAP_EXCEEDED(
                state.riskConfig.borrowTokenCap, state.data.borrowTokenVault.totalSupply()
            );
        }
    }

    /// @notice Validate that the Variable Pool has enough liquidity to withdraw the amount of cash
    /// @dev Reverts if the Variable Pool does not have enough liquidity
    ///      This safety mechanism prevents takers from matching orders that could not be withdrawn from the Variable Pool.
    ///        Nevertheless, the Variable Pool may still fail to withdraw the cash due to other factors (such as a pause, etc),
    ///        which is understood as an acceptable risk, since it can be mitigated by a multicall.
    ///      This check can be bypassed with a sandwitch attack that supplies just enough to make the pool liquid again,
    ///        which we understand as an acceptable risk, since it can be mitigated by a multicall.
    /// @param state The state struct
    /// @param amount The amount of cash to withdraw
    function validateVariablePoolHasEnoughLiquidity(State storage state, uint256 amount) public view {
        // TODO: implement or deprecate
    }
}
