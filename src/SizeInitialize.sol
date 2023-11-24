// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {PERCENT} from "./libraries/MathLibrary.sol";

import {ISize} from "./interfaces/ISize.sol";
import {SizeView} from "./SizeView.sol";
import {OfferLibrary, LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";

import {IPriceFeed} from "./oracle/IPriceFeed.sol";

struct SizeInitializeParams {
    address owner;
    address priceFeed;
    uint256 CROpening;
    uint256 CRLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
}

abstract contract SizeInitialize is SizeView, ISize {
    function _validateInitialize(SizeInitializeParams memory params) internal pure {
        // validate owner
        if (params.owner == address(0)) {
            revert ERROR_NULL_ADDRESS();
        }

        // validate price feed
        if (params.priceFeed == address(0)) {
            revert ERROR_NULL_ADDRESS();
        }

        // validate CROpening
        if (params.CROpening < PERCENT) {
            revert ERROR_INVALID_COLLATERAL_RATIO(params.CROpening);
        }

        // validate CRLiquidation
        if (params.CRLiquidation < PERCENT) {
            revert ERROR_INVALID_COLLATERAL_RATIO(params.CRLiquidation);
        }
        if (params.CROpening <= params.CRLiquidation) {
            revert ERROR_INVALID_LIQUIDATION_COLLATERAL_RATIO(params.CROpening, params.CRLiquidation);
        }

        // validate collateralPercentagePremiumToLiquidator
        if (params.collateralPercentagePremiumToLiquidator > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM(params.collateralPercentagePremiumToLiquidator);
        }

        // validate collateralPercentagePremiumToBorrower
        if (params.collateralPercentagePremiumToBorrower > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM(params.collateralPercentagePremiumToBorrower);
        }
        if (params.collateralPercentagePremiumToLiquidator + params.collateralPercentagePremiumToBorrower > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                params.collateralPercentagePremiumToLiquidator, params.collateralPercentagePremiumToBorrower
            );
        }
    }

    function _executeInitialize(SizeInitializeParams memory params) internal {
        priceFeed = IPriceFeed(params.priceFeed);
        CROpening = params.CROpening;
        CRLiquidation = params.CRLiquidation;
        collateralPercentagePremiumToLiquidator = params.collateralPercentagePremiumToLiquidator;
        collateralPercentagePremiumToBorrower = params.collateralPercentagePremiumToBorrower;

        // NOTE Necessary so that loanIds start at 1, and 0 is reserved for SOLs
        Loan memory l;
        loans.push(l);
    }
}
