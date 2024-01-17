// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {WadRayMath} from "@src/libraries/variable/WadRayMathLibrary.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";
import {ScaledBorrowToken} from "@src/token/ScaledBorrowToken.sol";
import {ScaledDebtToken} from "@src/token/ScaledDebtToken.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct InitializeGeneralParams {
    address owner;
    address priceFeed;
    address collateralAsset;
    address borrowAsset;
    address feeRecipient;
}

struct InitializeFixedParams {
    address collateralToken;
    address borrowToken;
    address debtToken;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPremiumToLiquidator;
    uint256 collateralPremiumToProtocol;
    uint256 minimumCredit;
}

struct InitializeVariableParams {
    uint256 minimumCollateralRatio;
    uint256 minRate;
    uint256 maxRate;
    uint256 slope;
    uint256 optimalUR;
    uint256 reserveFactor;
    address collateralToken;
    address scaledBorrowToken;
    address scaledDebtToken;
}

library Initialize {
    function _validateInitializeGeneralParams(InitializeGeneralParams memory g) internal pure {
        // validate owner
        // OwnableUpgradeable already performs this check

        // validate price feed
        if (g.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate collateral asset
        if (g.collateralAsset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate borrow asset
        if (g.borrowAsset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate feeRecipient
        if (g.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function _validateInitializeFixedParams(InitializeFixedParams memory f) internal pure {
        // validate collateral token
        if (f.collateralToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate borrow token
        if (f.borrowToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate debt token
        if (f.debtToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate crOpening
        if (f.crOpening < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(f.crOpening);
        }

        // validate crLiquidation
        if (f.crLiquidation < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(f.crLiquidation);
        }
        if (f.crOpening <= f.crLiquidation) {
            revert Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO(f.crOpening, f.crLiquidation);
        }

        // validate collateralPremiumToLiquidator
        if (f.collateralPremiumToLiquidator > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralPremiumToLiquidator);
        }

        // validate collateralPremiumToProtocol
        if (f.collateralPremiumToProtocol > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralPremiumToProtocol);
        }
        if (f.collateralPremiumToLiquidator + f.collateralPremiumToProtocol > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                f.collateralPremiumToLiquidator + f.collateralPremiumToProtocol
            );
        }

        // validate minimumCredit
        if (f.minimumCredit == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function _validateInitializeVariableParams(InitializeVariableParams memory v) internal pure {
        // validate minimumCollateralRatio
        if (v.minimumCollateralRatio < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(v.minimumCollateralRatio);
        }

        // validate minRate
        // N/A

        // validate maxRate
        // N/A

        // validate slope
        // N/A

        // validate optimalUR
        if (v.optimalUR > PERCENT) {
            revert Errors.INVALID_UR(v.optimalUR);
        }

        // validate reserveFactor
        if (v.reserveFactor > PERCENT) {
            revert Errors.INVALID_RESERVE_FACTOR(v.reserveFactor);
        }

        // TODO validate sum?

        // validate collateralToken
        if (v.collateralToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate scaledBorrowToken
        if (v.scaledBorrowToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate scaledDebtToken
        if (v.scaledDebtToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitialize(
        State storage,
        InitializeGeneralParams memory g,
        InitializeFixedParams memory f,
        InitializeVariableParams memory v
    ) external pure {
        _validateInitializeGeneralParams(g);
        _validateInitializeFixedParams(f);
        _validateInitializeVariableParams(v);
    }

    function _executeInitializeGeneral(State storage state, InitializeGeneralParams memory g) internal {
        state._general.priceFeed = IPriceFeed(g.priceFeed);
        state._general.collateralAsset = IERC20Metadata(g.collateralAsset);
        state._general.borrowAsset = IERC20Metadata(g.borrowAsset);
        state._general.feeRecipient = g.feeRecipient;
        state._general.variablePool = address(this);
    }

    function _executeInitializeFixed(State storage state, InitializeFixedParams memory f) internal {
        state._fixed.collateralToken = CollateralToken(f.collateralToken);
        state._fixed.borrowToken = BorrowToken(f.borrowToken);
        state._fixed.debtToken = DebtToken(f.debtToken);
        state._fixed.crOpening = f.crOpening;
        state._fixed.crLiquidation = f.crLiquidation;
        state._fixed.collateralPremiumToLiquidator = f.collateralPremiumToLiquidator;
        state._fixed.collateralPremiumToProtocol = f.collateralPremiumToProtocol;
        state._fixed.minimumCredit = f.minimumCredit;
    }

    function _executeInitializeVariable(State storage state, InitializeVariableParams memory v) internal {
        state._variable.minimumCollateralRatio = v.minimumCollateralRatio;
        state._variable.minRate = v.minRate;
        state._variable.maxRate = v.maxRate;
        state._variable.slope = v.slope;
        state._variable.optimalUR = v.optimalUR;
        state._variable.reserveFactor = v.reserveFactor;
        state._variable.liquidityIndexSupplyRAY = WadRayMath.RAY;
        state._variable.liquidityIndexBorrowRAY = WadRayMath.RAY;
        state._variable.lastUpdate = block.timestamp;
        state._variable.collateralToken = CollateralToken(v.collateralToken);
        state._variable.scaledBorrowToken = ScaledBorrowToken(v.scaledBorrowToken);
        state._variable.scaledDebtToken = ScaledDebtToken(v.scaledDebtToken);
    }

    function executeInitialize(
        State storage state,
        InitializeGeneralParams memory g,
        InitializeFixedParams memory f,
        InitializeVariableParams memory v
    ) external {
        _executeInitializeGeneral(state, g);
        _executeInitializeFixed(state, f);
        _executeInitializeVariable(state, v);
        emit Events.Initialize(g, f, v);
    }
}
