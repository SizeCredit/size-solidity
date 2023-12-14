// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct InitializeParams {
    address owner;
    address priceFeed;
    address collateralAsset;
    address borrowAsset;
    address collateralToken;
    address borrowToken;
    address debtToken;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
    address protocolVault;
    address feeRecipient;
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

        // validate collateral token
        if (params.collateralToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate borrow token
        if (params.borrowToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate debt token
        if (params.debtToken == address(0)) {
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

        // validate protocolVault
        if (params.protocolVault == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate feeRecipient
        if (params.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function executeInitialize(State storage state, InitializeParams memory params) external {
        state.priceFeed = IPriceFeed(params.priceFeed);
        state.collateralAsset = IERC20Metadata(params.collateralAsset);
        state.borrowAsset = IERC20Metadata(params.borrowAsset);
        state.collateralToken = CollateralToken(params.collateralToken);
        state.borrowToken = BorrowToken(params.borrowToken);
        state.debtToken = DebtToken(params.debtToken);
        state.crOpening = params.crOpening;
        state.crLiquidation = params.crLiquidation;
        state.collateralPercentagePremiumToLiquidator = params.collateralPercentagePremiumToLiquidator;
        state.collateralPercentagePremiumToBorrower = params.collateralPercentagePremiumToBorrower;
        state.protocolVault = params.protocolVault;
        state.feeRecipient = params.feeRecipient;
    }
}
