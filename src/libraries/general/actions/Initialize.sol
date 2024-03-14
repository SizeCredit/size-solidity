// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {Vault} from "@src/proxy/Vault.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct InitializeFeeConfigParams {
    uint256 repayFeeAPR;
    uint256 earlyLenderExitFee;
    uint256 earlyBorrowerExitFee;
    uint256 collateralOverdueTransferFee;
    address feeRecipient;
}

struct InitializeRiskConfigParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 collateralSplitLiquidatorPercent;
    uint256 collateralSplitProtocolPercent;
    uint256 collateralTokenCap;
    uint256 borrowATokenCap;
    uint256 debtTokenCap;
    uint256 moveToVariablePoolHFThreshold;
    uint256 minimumMaturity;
}

struct InitializeOracleParams {
    address priceFeed;
    address marketBorrowRateFeed;
}

struct InitializeDataParams {
    address underlyingCollateralToken;
    address underlyingBorrowToken;
    address variablePool;
}

/// @title Initialize
/// @notice Contains the logic to initialize the protocol
/// @dev The collateralToken (e.g. szETH) and debtToken (e.g. szDebt) are created in the `executeInitialize` function
///      The borrowAToken (e.g. aszUSDC) is deployed on the Size Variable Pool (Aave v3 fork)
library Initialize {
    function validateOwner(address owner) internal pure {
        if (owner == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitializeFeeConfigParams(InitializeFeeConfigParams memory f) internal pure {
        // validate repayFeeAPR
        // N/A

        // validate earlyLenderExitFee
        // N/A

        // validate earlyBorrowerExitFee
        // N/A

        // validate collateralOverdueTransferFee
        // N/A

        // validate feeRecipient
        if (f.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitializeRiskConfigParams(InitializeRiskConfigParams memory r) internal pure {
        // validate crOpening
        if (r.crOpening < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(r.crOpening);
        }

        // validate crLiquidation
        if (r.crLiquidation < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(r.crLiquidation);
        }
        if (r.crOpening <= r.crLiquidation) {
            revert Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO(r.crOpening, r.crLiquidation);
        }

        // validate minimumCreditBorrowAToken
        if (r.minimumCreditBorrowAToken == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate collateralSplitLiquidatorPercent
        if (r.collateralSplitLiquidatorPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(r.collateralSplitLiquidatorPercent);
        }

        // validate collateralSplitProtocolPercent
        if (r.collateralSplitProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(r.collateralSplitProtocolPercent);
        }
        if (r.collateralSplitLiquidatorPercent + r.collateralSplitProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                r.collateralSplitLiquidatorPercent + r.collateralSplitProtocolPercent
            );
        }

        // validate underlyingCollateralTokenCap
        // N/A

        // validate underlyingBorrowTokenCap
        // N/A

        // validate debtTokenCap
        // N/A

        // validate moveToVariablePoolHFThreshold
        if (r.moveToVariablePoolHFThreshold < PERCENT) {
            revert Errors.INVALID_MOVE_TO_VARIABLE_POOL_HF_THRESHOLD(r.moveToVariablePoolHFThreshold);
        }
    }

    function validateInitializeOracleParams(InitializeOracleParams memory o) internal view {
        // validate priceFeed
        if (o.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        IPriceFeed(o.priceFeed).getPrice();

        // validate marketBorrowRateFeed
        if (o.marketBorrowRateFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        IMarketBorrowRateFeed(o.marketBorrowRateFeed).getMarketBorrowRate();
    }

    function validateInitializeDataParams(InitializeDataParams memory d) internal pure {
        // validate underlyingCollateralToken
        if (d.underlyingCollateralToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate underlyingBorrowToken
        if (d.underlyingBorrowToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate variablePool
        if (d.variablePool == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitialize(
        State storage,
        address owner,
        InitializeFeeConfigParams memory f,
        InitializeRiskConfigParams memory r,
        InitializeOracleParams memory o,
        InitializeDataParams memory d
    ) external view {
        validateOwner(owner);
        validateInitializeFeeConfigParams(f);
        validateInitializeRiskConfigParams(r);
        validateInitializeOracleParams(o);
        validateInitializeDataParams(d);
    }

    function executeInitializeFeeConfig(State storage state, InitializeFeeConfigParams memory f) internal {
        state.feeConfig.repayFeeAPR = f.repayFeeAPR;

        state.feeConfig.earlyLenderExitFee = f.earlyLenderExitFee;
        state.feeConfig.earlyBorrowerExitFee = f.earlyBorrowerExitFee;

        state.feeConfig.collateralOverdueTransferFee = f.collateralOverdueTransferFee;

        state.feeConfig.feeRecipient = f.feeRecipient;
    }

    function executeInitializeRiskConfig(State storage state, InitializeRiskConfigParams memory r) internal {
        state.riskConfig.crOpening = r.crOpening;
        state.riskConfig.crLiquidation = r.crLiquidation;

        state.riskConfig.minimumCreditBorrowAToken = r.minimumCreditBorrowAToken;

        state.riskConfig.collateralSplitLiquidatorPercent = r.collateralSplitLiquidatorPercent;
        state.riskConfig.collateralSplitProtocolPercent = r.collateralSplitProtocolPercent;

        state.riskConfig.collateralTokenCap = r.collateralTokenCap;
        state.riskConfig.borrowATokenCap = r.borrowATokenCap;
        state.riskConfig.debtTokenCap = r.debtTokenCap;

        state.riskConfig.moveToVariablePoolHFThreshold = r.moveToVariablePoolHFThreshold;
        state.riskConfig.minimumMaturity = r.minimumMaturity;
    }

    function executeInitializeOracle(State storage state, InitializeOracleParams memory o) internal {
        state.oracle.priceFeed = IPriceFeed(o.priceFeed);
        state.oracle.marketBorrowRateFeed = IMarketBorrowRateFeed(o.marketBorrowRateFeed);
    }

    function executeInitializeData(State storage state, InitializeDataParams memory d) internal {
        state.data.underlyingCollateralToken = IERC20Metadata(d.underlyingCollateralToken);
        state.data.underlyingBorrowToken = IERC20Metadata(d.underlyingBorrowToken);
        state.data.variablePool = IPool(d.variablePool);

        state.data.collateralToken = new NonTransferrableToken(
            address(this),
            string.concat("Size Fixed ", IERC20Metadata(state.data.underlyingCollateralToken).name()),
            string.concat("sz", IERC20Metadata(state.data.underlyingCollateralToken).symbol()),
            IERC20Metadata(state.data.underlyingCollateralToken).decimals()
        );
        state.data.borrowAToken =
            IAToken(state.data.variablePool.getReserveData(address(state.data.underlyingBorrowToken)).aTokenAddress);
        state.data.collateralAToken =
            IAToken(state.data.variablePool.getReserveData(address(state.data.underlyingCollateralToken)).aTokenAddress);
        state.data.debtToken = new NonTransferrableToken(
            address(this), "Size Fixed Debt", "szDebt", IERC20Metadata(state.data.underlyingBorrowToken).decimals()
        );

        state.data.vaultImplementation = new Vault();
    }

    function executeInitialize(
        State storage state,
        InitializeFeeConfigParams memory f,
        InitializeRiskConfigParams memory r,
        InitializeOracleParams memory o,
        InitializeDataParams memory d
    ) external {
        executeInitializeFeeConfig(state, f);
        executeInitializeRiskConfig(state, r);
        executeInitializeOracle(state, o);
        executeInitializeData(state, d);
        emit Events.Initialize(f, r, o, d);
    }
}
