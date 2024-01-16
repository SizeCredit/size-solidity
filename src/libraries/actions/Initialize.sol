// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {State} from "@src/SizeStorage.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

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
    address variablePool;
    address feeRecipient;
}

struct InitializeExtraParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPremiumToLiquidator;
    uint256 collateralPremiumToProtocol;
    uint256 minimumCredit;
}

library Initialize {
    function validateInitialize(State storage, InitializeParams memory params, InitializeExtraParams memory extraParams)
        external
        pure
    {
        // validate owner
        // OwnableUpgradeable already performs this check

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

        // validate variablePool
        if (params.variablePool == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate price feed
        if (params.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate feeRecipient
        if (params.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate crOpening
        if (extraParams.crOpening < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(extraParams.crOpening);
        }

        // validate crLiquidation
        if (extraParams.crLiquidation < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(extraParams.crLiquidation);
        }
        if (extraParams.crOpening <= extraParams.crLiquidation) {
            revert Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO(extraParams.crOpening, extraParams.crLiquidation);
        }

        // validate collateralPremiumToLiquidator
        if (extraParams.collateralPremiumToLiquidator > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(extraParams.collateralPremiumToLiquidator);
        }

        // validate collateralPremiumToProtocol
        if (extraParams.collateralPremiumToProtocol > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(extraParams.collateralPremiumToProtocol);
        }
        if (extraParams.collateralPremiumToLiquidator + extraParams.collateralPremiumToProtocol > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                extraParams.collateralPremiumToLiquidator + extraParams.collateralPremiumToProtocol
            );
        }

        // validate minimumCredit
        if (extraParams.minimumCredit == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeInitialize(
        State storage state,
        InitializeParams memory params,
        InitializeExtraParams memory extraParams
    ) external {
        state.g.collateralAsset = IERC20Metadata(params.collateralAsset);
        state.g.borrowAsset = IERC20Metadata(params.borrowAsset);
        state.f.collateralToken = CollateralToken(params.collateralToken);
        state.f.borrowToken = BorrowToken(params.borrowToken);
        state.f.debtToken = DebtToken(params.debtToken);
        state.g.variablePool = params.variablePool;
        state.g.priceFeed = IPriceFeed(params.priceFeed);
        state.g.feeRecipient = params.feeRecipient;
        state.f.crOpening = extraParams.crOpening;
        state.f.crLiquidation = extraParams.crLiquidation;
        state.f.collateralPremiumToLiquidator = extraParams.collateralPremiumToLiquidator;
        state.f.collateralPremiumToProtocol = extraParams.collateralPremiumToProtocol;
        state.f.minimumCredit = extraParams.minimumCredit;

        // TODO separate in initializeFixed, initializeVariable, initializeGeneral

        state.v.lastUpdate = block.timestamp;
        state.v.liquidityIndexSupplyRAY = PERCENT;
        state.v.liquidityIndexBorrowRAY = PERCENT;
    }
}
