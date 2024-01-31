// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

library CapsLibrary {
    function validateCollateralTokenCap(State storage state) external view {
        if (state._fixed.collateralToken.totalSupply() > state._fixed.collateralTokenCap) {
            revert Errors.COLLATERAL_TOKEN_CAP_EXCEEDED();
        }
    }

    function validateBorrowATokenCap(State storage state) external view {
        if (state._fixed.borrowAToken.totalSupply() > state._fixed.borrowATokenCap) {
            revert Errors.BORROW_ATOKEN_CAP_EXCEEDED();
        }
    }

    function validateDebtTokenCap(State storage state) external view {
        if (state._fixed.debtToken.totalSupply() > state._fixed.debtTokenCap) {
            revert Errors.DEBT_TOKEN_CAP_EXCEEDED();
        }
    }
}
