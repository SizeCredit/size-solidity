// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START} from "@src/libraries/fixed/LoanLibrary.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {Vault} from "@src/proxy/Vault.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct InitializeConfigParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 collateralSplitLiquidatorPercent;
    uint256 collateralSplitProtocolPercent;
    uint256 collateralTokenCap;
    uint256 borrowATokenCap;
    uint256 debtTokenCap;
    uint256 repayFeeAPR;
    uint256 earlyLenderExitFee;
    uint256 earlyBorrowerExitFee;
    uint256 collateralOverdueTransferFee;
    address feeRecipient;
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

    function validateInitializeConfigParams(InitializeConfigParams memory c) internal pure {
        // validate crOpening
        if (c.crOpening < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(c.crOpening);
        }

        // validate crLiquidation
        if (c.crLiquidation < PERCENT) {
            revert Errors.INVALID_COLLATERAL_RATIO(c.crLiquidation);
        }
        if (c.crOpening <= c.crLiquidation) {
            revert Errors.INVALID_LIQUIDATION_COLLATERAL_RATIO(c.crOpening, c.crLiquidation);
        }

        // validate minimumCreditBorrowAToken
        if (c.minimumCreditBorrowAToken == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate collateralSplitLiquidatorPercent
        if (c.collateralSplitLiquidatorPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(c.collateralSplitLiquidatorPercent);
        }

        // validate collateralSplitProtocolPercent
        if (c.collateralSplitProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(c.collateralSplitProtocolPercent);
        }
        if (c.collateralSplitLiquidatorPercent + c.collateralSplitProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                c.collateralSplitLiquidatorPercent + c.collateralSplitProtocolPercent
            );
        }

        // validate underlyingCollateralTokenCap
        // N/A

        // validate underlyingBorrowTokenCap
        // N/A

        // validate debtTokenCap
        // N/A

        // validate repayFeeAPR
        // N/A

        // validate earlyLenderExitFee
        // N/A

        // validate earlyBorrowerExitFee
        // N/A

        // validate feeRecipient
        if (c.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitializeOracleParams(InitializeOracleParams memory o) internal pure {
        // validate price feed
        if (o.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate marketBorrowRateFeed
        if (o.marketBorrowRateFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate collateralOverdueTransferFee
        // N/A
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
        InitializeConfigParams memory c,
        InitializeOracleParams memory o,
        InitializeDataParams memory d
    ) external pure {
        validateOwner(owner);
        validateInitializeConfigParams(c);
        validateInitializeOracleParams(o);
        validateInitializeDataParams(d);
    }

    function executeInitializeConfig(State storage state, InitializeConfigParams memory c) internal {
        state.config.crOpening = c.crOpening;
        state.config.crLiquidation = c.crLiquidation;

        state.config.minimumCreditBorrowAToken = c.minimumCreditBorrowAToken;

        state.config.collateralSplitLiquidatorPercent = c.collateralSplitLiquidatorPercent;
        state.config.collateralSplitProtocolPercent = c.collateralSplitProtocolPercent;

        state.config.collateralTokenCap = c.collateralTokenCap;
        state.config.borrowATokenCap = c.borrowATokenCap;
        state.config.debtTokenCap = c.debtTokenCap;

        state.config.repayFeeAPR = c.repayFeeAPR;

        state.config.earlyLenderExitFee = c.earlyLenderExitFee;
        state.config.earlyBorrowerExitFee = c.earlyBorrowerExitFee;

        state.config.collateralOverdueTransferFee = c.collateralOverdueTransferFee;

        state.config.feeRecipient = c.feeRecipient;
    }

    function executeInitializeOracle(State storage state, InitializeOracleParams memory o) internal {
        state.oracle.priceFeed = IPriceFeed(o.priceFeed);
        state.oracle.marketBorrowRateFeed = IMarketBorrowRateFeed(o.marketBorrowRateFeed);
    }

    function executeInitializeData(State storage state, InitializeDataParams memory d) internal {
        state.data.nextDebtPositionId = DEBT_POSITION_ID_START;
        state.data.nextCreditPositionId = CREDIT_POSITION_ID_START;

        state.data.underlyingCollateralToken = IERC20Metadata(d.underlyingCollateralToken);
        state.data.underlyingBorrowToken = IERC20Metadata(d.underlyingBorrowToken);
        state.data.variablePool = IPool(d.variablePool);

        state.data.collateralToken = new NonTransferrableToken(
            address(this), "Size Fixed ETH", "szETH", IERC20Metadata(state.data.underlyingCollateralToken).decimals()
        );
        state.data.borrowAToken =
            IAToken(state.data.variablePool.getReserveData(address(state.data.underlyingBorrowToken)).aTokenAddress);
        state.data.debtToken = new NonTransferrableToken(
            address(this), "Size Debt", "szDebt", IERC20Metadata(state.data.underlyingBorrowToken).decimals()
        );

        state.data.vaultImplementation = new Vault();
    }

    function executeInitialize(
        State storage state,
        InitializeConfigParams memory c,
        InitializeOracleParams memory o,
        InitializeDataParams memory d
    ) external {
        executeInitializeConfig(state, c);
        executeInitializeOracle(state, o);
        executeInitializeData(state, d);
        emit Events.Initialize(c, o, d);
    }
}
