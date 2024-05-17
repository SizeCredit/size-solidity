// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START} from "@src/libraries/fixed/LoanLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct InitializeFeeConfigParams {
    uint256 swapFeeAPR;
    uint256 fragmentationFee;
    uint256 liquidationRewardPercent;
    uint256 collateralLiquidatorPercent;
    uint256 collateralProtocolPercent;
    address feeRecipient;
}

struct InitializeRiskConfigParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 borrowATokenCap;
    uint256 debtTokenCap;
    uint256 minimumMaturity;
}

struct InitializeOracleParams {
    address priceFeed;
    address variablePoolBorrowRateFeed;
}

struct InitializeDataParams {
    address weth;
    address underlyingCollateralToken;
    address underlyingBorrowToken;
    address variablePool;
}

/// @title Initialize
/// @notice Contains the logic to initialize the protocol
/// @dev The collateralToken (e.g. szETH) and debtToken (e.g. szDebt) are created in the `executeInitialize` function
///      The borrowAToken (e.g. aUSDC) is deployed on the Variable Pool (Aave v3)
library Initialize {
    function validateOwner(address owner) internal pure {
        if (owner == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitializeFeeConfigParams(InitializeFeeConfigParams memory f) internal pure {
        // validate swapFeeAPR
        // N/A

        // validate fragmentationFee
        // N/A

        // validate collateralLiquidatorPercent
        if (f.collateralLiquidatorPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralLiquidatorPercent);
        }

        // validate liquidationRewardPercent
        // N/A

        // validate collateralProtocolPercent
        if (f.collateralProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralProtocolPercent);
        }
        if (f.collateralLiquidatorPercent + f.collateralProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(
                f.collateralLiquidatorPercent + f.collateralProtocolPercent
            );
        }

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

        // validate underlyingBorrowTokenCap
        // N/A

        // validate debtTokenCap
        // N/A

        // validate minimumMaturity
        if (r.minimumMaturity == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function validateInitializeOracleParams(InitializeOracleParams memory o) internal view {
        // validate priceFeed
        if (o.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        // slither-disable-next-line unused-return
        IPriceFeed(o.priceFeed).getPrice();

        // validate variablePoolBorrowRateFeed
        if (o.variablePoolBorrowRateFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    function validateInitializeDataParams(InitializeDataParams memory d) internal view {
        // validate underlyingCollateralToken
        if (d.underlyingCollateralToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (IERC20Metadata(d.underlyingCollateralToken).decimals() > 18) {
            revert Errors.INVALID_DECIMALS(IERC20Metadata(d.underlyingCollateralToken).decimals());
        }

        // validate underlyingBorrowToken
        if (d.underlyingBorrowToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (IERC20Metadata(d.underlyingBorrowToken).decimals() > 18) {
            revert Errors.INVALID_DECIMALS(IERC20Metadata(d.underlyingBorrowToken).decimals());
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
        state.feeConfig.swapFeeAPR = f.swapFeeAPR;
        state.feeConfig.fragmentationFee = f.fragmentationFee;

        state.feeConfig.liquidationRewardPercent = f.liquidationRewardPercent;
        state.feeConfig.collateralLiquidatorPercent = f.collateralLiquidatorPercent;
        state.feeConfig.collateralProtocolPercent = f.collateralProtocolPercent;

        state.feeConfig.feeRecipient = f.feeRecipient;
    }

    function executeInitializeRiskConfig(State storage state, InitializeRiskConfigParams memory r) internal {
        state.riskConfig.crOpening = r.crOpening;
        state.riskConfig.crLiquidation = r.crLiquidation;

        state.riskConfig.minimumCreditBorrowAToken = r.minimumCreditBorrowAToken;

        state.riskConfig.borrowATokenCap = r.borrowATokenCap;
        state.riskConfig.debtTokenCap = r.debtTokenCap;

        state.riskConfig.minimumMaturity = r.minimumMaturity;
    }

    function executeInitializeOracle(State storage state, InitializeOracleParams memory o) internal {
        state.oracle.priceFeed = IPriceFeed(o.priceFeed);
        state.oracle.variablePoolBorrowRateFeed = IVariablePoolBorrowRateFeed(o.variablePoolBorrowRateFeed);
    }

    function executeInitializeData(State storage state, InitializeDataParams memory d) internal {
        state.data.nextDebtPositionId = DEBT_POSITION_ID_START;
        state.data.nextCreditPositionId = CREDIT_POSITION_ID_START;

        state.data.weth = IWETH(d.weth);
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
        state.data.debtToken = new NonTransferrableToken(
            address(this), "Size Fixed Debt", "szDebt", IERC20Metadata(state.data.underlyingBorrowToken).decimals()
        );
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
