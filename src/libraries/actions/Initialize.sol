// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct InitializeParams {
    address owner;
    address priceFeed;
    address collateralAsset;
    address borrowAsset;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
}

library Initialize {
    function validateInitialize(State storage, InitializeParams memory params) external pure {
        // validate owner
        if (params.owner == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate price feed
        if (params.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate collateral asset
        if (params.collateralAsset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate borrow asset
        if (params.borrowAsset == address(0)) {
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
    }

    function executeInitialize(State storage state, InitializeParams memory params) external {
        state.priceFeed = IPriceFeed(params.priceFeed);
        state.collateralAsset = IERC20Metadata(params.collateralAsset);
        state.borrowAsset = IERC20Metadata(params.borrowAsset);
        state.crOpening = params.crOpening;
        state.crLiquidation = params.crLiquidation;
        state.collateralPercentagePremiumToLiquidator = params.collateralPercentagePremiumToLiquidator;
        state.collateralPercentagePremiumToBorrower = params.collateralPercentagePremiumToBorrower;

        // NOTE Necessary so that loanIds start at 1, and 0 is reserved for SOLs
        Loan memory nullLoan;
        state.loans.push(nullLoan);
    }
}
