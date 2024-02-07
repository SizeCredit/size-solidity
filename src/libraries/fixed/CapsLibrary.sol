// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

library CapsLibrary {
    function validateCollateralTokenCap(State storage state) external view {
        if (state.data.collateralToken.totalSupply() > state.config.collateralTokenCap) {
            revert Errors.COLLATERAL_TOKEN_CAP_EXCEEDED(
                state.config.collateralTokenCap, state.data.collateralToken.totalSupply()
            );
        }
    }

    function validateBorrowATokenCap(State storage state) external view {
        if (state.data.borrowAToken.totalSupply() > state.config.borrowATokenCap) {
            revert Errors.BORROW_ATOKEN_CAP_EXCEEDED(
                state.config.borrowATokenCap, state.data.borrowAToken.totalSupply()
            );
        }
    }

    function validateDebtTokenCap(State storage state) external view {
        if (state.data.debtToken.totalSupply() > state.config.debtTokenCap) {
            revert Errors.DEBT_TOKEN_CAP_EXCEEDED(state.config.debtTokenCap, state.data.debtToken.totalSupply());
        }
    }
}
