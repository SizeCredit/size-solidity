// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {PERCENT} from "./libraries/MathLibrary.sol";

import {ISize} from "./interfaces/ISize.sol";
import {SizeView} from "./SizeView.sol";
import {OfferLibrary, LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";

abstract contract SizeSecurityValidations is SizeView, ISize {
    using UserLibrary for User;

    function _validateUserIsNotLiquidatable(address account) internal view {
        if (isLiquidatable(account)) {
            revert ERROR_USER_IS_LIQUIDATABLE(account, users[account].collateralRatio(priceFeed.getPrice()));
        }
    }
}

abstract contract SizeInputValidations is SizeView, ISize {
    function _validateNonNull(address account) internal pure {
        if (account == address(0)) {
            revert ERROR_NULL_ADDRESS();
        }
    }

    function _validateCollateralRatio(uint256 cr) internal pure {
        if (cr < PERCENT) {
            revert ERROR_INVALID_COLLATERAL_RATIO(cr);
        }
    }

    function _validateCollateralRatio(uint256 crOpening, uint256 crLiquidation) internal pure {
        if (crOpening <= crLiquidation) {
            revert ERROR_INVALID_LIQUIDATION_COLLATERAL_RATIO(crOpening, crLiquidation);
        }
    }

    function _validateCollateralPercentagePremium(uint256 percentage) internal pure {
        if (percentage > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM(percentage);
        }
    }

    function _validateCollateralPercentagePremium(uint256 a, uint256 b) internal pure {
        if (a + b > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(a, b);
        }
    }

    function _validateDueDate(uint256 dueDate) internal view {}
}

abstract contract SizeValidations is SizeSecurityValidations, SizeInputValidations {}
