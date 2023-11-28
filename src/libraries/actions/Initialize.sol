// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {ISize} from "@src/interfaces/ISize.sol";
import {SizeView} from "@src/SizeView.sol";
import {OfferLibrary, LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {State} from "@src/SizeStorage.sol";

import {Error} from "@src/libraries/Error.sol";

struct InitializeParams {
    address owner;
    address priceFeed;
    address collateralAsset;
    address borrowAsset;
    uint256 CROpening;
    uint256 CRLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
}

library Initialize {
    function validateInitialize(State storage, InitializeParams memory params) external pure {
        // validate owner
        if (params.owner == address(0)) {
            revert Error.NULL_ADDRESS();
        }

        // validate price feed
        if (params.priceFeed == address(0)) {
            revert Error.NULL_ADDRESS();
        }

        // validate collateral asset
        if (params.collateralAsset == address(0)) {
            revert Error.NULL_ADDRESS();
        }

        // validate borrow asset
        if (params.borrowAsset == address(0)) {
            revert Error.NULL_ADDRESS();
        }

        // validate CROpening
        if (params.CROpening < PERCENT) {
            revert Error.INVALID_COLLATERAL_RATIO(params.CROpening);
        }

        // validate CRLiquidation
        if (params.CRLiquidation < PERCENT) {
            revert Error.INVALID_COLLATERAL_RATIO(params.CRLiquidation);
        }
        if (params.CROpening <= params.CRLiquidation) {
            revert Error.INVALID_LIQUIDATION_COLLATERAL_RATIO(params.CROpening, params.CRLiquidation);
        }

        // validate collateralPercentagePremiumToLiquidator
        if (params.collateralPercentagePremiumToLiquidator > PERCENT) {
            revert Error.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(params.collateralPercentagePremiumToLiquidator);
        }

        // validate collateralPercentagePremiumToBorrower
        if (params.collateralPercentagePremiumToBorrower > PERCENT) {
            revert Error.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(params.collateralPercentagePremiumToBorrower);
        }
        if (params.collateralPercentagePremiumToLiquidator + params.collateralPercentagePremiumToBorrower > PERCENT) {
            revert Error.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                params.collateralPercentagePremiumToLiquidator, params.collateralPercentagePremiumToBorrower
            );
        }
    }

    function executeInitialize(State storage state, InitializeParams memory params) external {
        state.priceFeed = IPriceFeed(params.priceFeed);
        state.collateralAsset = IERC20(params.collateralAsset);
        state.borrowAsset = IERC20(params.borrowAsset);
        state.CROpening = params.CROpening;
        state.CRLiquidation = params.CRLiquidation;
        state.collateralPercentagePremiumToLiquidator = params.collateralPercentagePremiumToLiquidator;
        state.collateralPercentagePremiumToBorrower = params.collateralPercentagePremiumToBorrower;

        // NOTE Necessary so that loanIds start at 1, and 0 is reserved for SOLs
        Loan memory l;
        state.loans.push(l);
    }
}
