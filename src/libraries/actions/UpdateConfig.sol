// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct UpdateConfigParams {
    address priceFeed;
    address feeRecipient;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
    uint256 minimumCredit;
}

library UpdateConfig {
    function validateUpdateConfig(State storage, UpdateConfigParams memory params) external pure {
        // validate price feed
        if (params.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate feeRecipient
        if (params.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate crOpening
        if (params.crOpening < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(params.crOpening);
        }

        // validate crLiquidation
        if (params.crLiquidation < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(params.crLiquidation);
        }
        if (params.crOpening <= params.crLiquidation) {
            revert Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO(params.crOpening, params.crLiquidation);
        }

        // validate collateralPercentagePremiumToLiquidator
        if (params.collateralPercentagePremiumToLiquidator > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(params.collateralPercentagePremiumToLiquidator);
        }

        // validate collateralPercentagePremiumToBorrower
        if (params.collateralPercentagePremiumToBorrower > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(params.collateralPercentagePremiumToBorrower);
        }
        if (params.collateralPercentagePremiumToLiquidator + params.collateralPercentagePremiumToBorrower > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                params.collateralPercentagePremiumToLiquidator + params.collateralPercentagePremiumToBorrower
            );
        }

        // validate minimumCredit
        if (params.minimumCredit == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeUpdateConfig(State storage state, UpdateConfigParams memory params) external {
        state.config.crOpening = params.crOpening;
        state.config.crLiquidation = params.crLiquidation;
        state.config.collateralPercentagePremiumToLiquidator = params.collateralPercentagePremiumToLiquidator;
        state.config.collateralPercentagePremiumToBorrower = params.collateralPercentagePremiumToBorrower;
        state.config.minimumCredit = params.minimumCredit;
        state.config.priceFeed = IPriceFeed(params.priceFeed);
        state.config.feeRecipient = params.feeRecipient;
    }
}
