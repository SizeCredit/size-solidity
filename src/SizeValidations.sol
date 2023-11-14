// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {PERCENT} from "./libraries/MathLibrary.sol";

import {ISize} from "./interfaces/ISize.sol";
import {SizeView} from "./SizeView.sol";

abstract contract SizeSecurityValidations is SizeView, ISize {
    function _validateUserHealthy(address account) internal {
        if (isLiquidatable(account)) {
            revert ISize.UserUnhealthy(account);
        }
    }
}

abstract contract SizeInputValidations is SizeView, ISize {
    function _validateNonNull(address account) internal pure {
        if (account == address(0)) {
            revert ISize.NullAddress();
        }
    }
    function _validateOfferId(uint256 offerId) internal {
        if (offerId == 0 || offerId >= loanOffers.length) {
            revert ISize.InvalidOfferId(offerId);
        }
    }
    function _validateCollateralRatio(uint256 cr) internal {
        if(cr < PERCENT) {
            revert InvalidCollateralRatio(cr);
        }
    }
    function _validateCollateralRatio(uint256 crOpening, uint256 crLiquidation) internal {
        if(crOpening <= crLiquidation) {
            revert InvalidLiquidationCollateralRatio(crOpening, crLiquidation);
        }
    }
}

abstract contract SizeValidations is
    SizeSecurityValidations,
    SizeInputValidations
{}
