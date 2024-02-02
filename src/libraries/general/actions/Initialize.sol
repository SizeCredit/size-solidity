// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {Vault} from "@src/proxy/Vault.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct InitializeGeneralParams {
    address owner;
    address priceFeed;
    address marketBorrowRateFeed;
    address collateralAsset;
    address borrowAsset;
    address feeRecipient;
    address variablePool;
}

struct InitializeFixedParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralSplitLiquidatorPercent;
    uint256 collateralSplitProtocolPercent;
    uint256 minimumCreditBorrowAsset;
    uint256 collateralTokenCap;
    uint256 borrowATokenCap;
    uint256 debtTokenCap;
    uint256 repayFeeAPR;
}

struct InitializeVariableParams {
    uint256 collateralOverdueTransferFee;
}

library Initialize {
    function _validateInitializeGeneralParams(InitializeGeneralParams memory g) internal pure {
        // validate owner
        if (g.owner == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate price feed
        if (g.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate marketBorrowRateFeed
        if (g.marketBorrowRateFeed == address(0)) {
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

        // validate collateralAssetCap
        // N/A

        // validate borrowAssetCap
        // N/A

        // validate debtCap
        // N/A

        // validate feeRecipient
        if (g.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function _validateInitializeFixedParams(InitializeFixedParams memory f) internal pure {
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

        // validate collateralSplitLiquidatorPercent
        if (f.collateralSplitLiquidatorPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralSplitLiquidatorPercent);
        }

        // validate collateralSplitProtocolPercent
        if (f.collateralSplitProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralSplitProtocolPercent);
        }
        if (f.collateralSplitLiquidatorPercent + f.collateralSplitProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                f.collateralSplitLiquidatorPercent + f.collateralSplitProtocolPercent
            );
        }

        // validate minimumCreditBorrowAsset
        if (f.minimumCreditBorrowAsset == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate repayFeeAPR
        // N/A
    }

    function _validateInitializeVariableParams(InitializeVariableParams memory) internal pure {
        // validate collateralOverdueTransferFee
        // N/A
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
        state._general.marketBorrowRateFeed = IMarketBorrowRateFeed(g.marketBorrowRateFeed);
        state._general.collateralAsset = IERC20Metadata(g.collateralAsset);
        state._general.borrowAsset = IERC20Metadata(g.borrowAsset);
        state._general.feeRecipient = g.feeRecipient;
        state._general.variablePool = IPool(g.variablePool);
    }

    function _executeInitializeFixed(State storage state, InitializeFixedParams memory f) internal {
        state._fixed.collateralToken = new CollateralToken(
            address(this), "Size Fixed ETH", "szETH", IERC20Metadata(state._general.collateralAsset).decimals()
        );
        state._fixed.borrowAToken =
            IAToken(state._general.variablePool.getReserveData(address(state._general.borrowAsset)).aTokenAddress);
        state._fixed.debtToken =
            new DebtToken(address(this), "Size Debt", "szDebt", IERC20Metadata(state._general.borrowAsset).decimals());

        state._fixed.crOpening = f.crOpening;
        state._fixed.crLiquidation = f.crLiquidation;
        state._fixed.collateralSplitLiquidatorPercent = f.collateralSplitLiquidatorPercent;
        state._fixed.collateralSplitProtocolPercent = f.collateralSplitProtocolPercent;
        state._fixed.minimumCreditBorrowAsset = f.minimumCreditBorrowAsset;

        state._fixed.collateralTokenCap = f.collateralTokenCap;
        state._fixed.borrowATokenCap = f.borrowATokenCap;
        state._fixed.debtTokenCap = f.debtTokenCap;

        state._fixed.repayFeeAPR = f.repayFeeAPR;
    }

    function _executeInitializeVariable(State storage state, InitializeVariableParams memory v) internal {
        state._variable.vaultImplementation = address(new Vault());
        state._variable.collateralOverdueTransferFee = v.collateralOverdueTransferFee;
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
