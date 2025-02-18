// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@src/market/interfaces/IWETH.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {CREDIT_POSITION_ID_START, DEBT_POSITION_ID_START} from "@src/market/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/market/libraries/Math.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {NonTransferrableScaledTokenV1_5} from "@src/market/token/NonTransferrableScaledTokenV1_5.sol";
import {NonTransferrableToken} from "@src/market/token/NonTransferrableToken.sol";

import {State} from "@src/market/SizeStorage.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

// See SizeStorage.sol for the definitions of the structs below
struct InitializeFeeConfigParams {
    uint256 swapFeeAPR;
    uint256 fragmentationFee;
    uint256 liquidationRewardPercent;
    uint256 overdueCollateralProtocolPercent;
    uint256 collateralProtocolPercent;
    address feeRecipient;
}

struct InitializeRiskConfigParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 borrowATokenCap;
    uint256 minTenor;
    uint256 maxTenor;
}

struct InitializeOracleParams {
    address priceFeed;
    uint64 variablePoolBorrowRateStaleRateInterval;
}

struct InitializeDataParams {
    address weth;
    address underlyingCollateralToken;
    address underlyingBorrowToken;
    address variablePool;
    address borrowATokenV1_5;
    address sizeFactory;
}

/// @title Initialize
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic to initialize the protocol
/// @dev The collateralToken (e.g. szETH) and debtToken (e.g. szDebt) are created in the `executeInitialize` function
///      The borrowAToken (e.g. szaUSDC) must have been deployed before the initialization
library Initialize {
    using SafeERC20 for IERC20;

    /// @notice Validates the owner address
    /// @param owner The owner address
    function validateOwner(address owner) internal pure {
        if (owner == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    /// @notice Validates the parameters for the fee configuration
    /// @param f The fee configuration parameters
    function validateInitializeFeeConfigParams(InitializeFeeConfigParams memory f) internal pure {
        // validate swapFeeAPR
        // N/A

        // validate fragmentationFee
        // N/A

        // validate liquidationRewardPercent
        // N/A

        // validate overdueCollateralProtocolPercent
        if (f.overdueCollateralProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.overdueCollateralProtocolPercent);
        }

        // validate collateralProtocolPercent
        if (f.collateralProtocolPercent > PERCENT) {
            revert Errors.INVALID_COLLATERAL_PERCENTAGE_PREMIUM(f.collateralProtocolPercent);
        }

        // validate feeRecipient
        if (f.feeRecipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    /// @notice Validates the parameters for the risk configuration
    /// @param r The risk configuration parameters
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

        // validate borrowATokenCap
        if (r.borrowATokenCap == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate minTenor
        if (r.minTenor == 0) {
            revert Errors.NULL_AMOUNT();
        }

        if (r.maxTenor <= r.minTenor) {
            revert Errors.INVALID_MAXIMUM_TENOR(r.maxTenor);
        }
    }

    /// @notice Validates the parameters for the oracle configuration
    /// @param o The oracle configuration parameters
    function validateInitializeOracleParams(InitializeOracleParams memory o) internal view {
        // validate priceFeed
        if (o.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        // slither-disable-next-line unused-return
        IPriceFeed(o.priceFeed).getPrice();

        // validate variablePoolBorrowRateStaleRateInterval
        // N/A
    }

    /// @notice Validates the parameters for the data configuration
    /// @param d The data configuration parameters
    function validateInitializeDataParams(InitializeDataParams memory d) internal view {
        // validate weth
        if (d.weth == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

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

        // validate borrowATokenV1_5
        if (d.borrowATokenV1_5 == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate sizeFactory
        if (d.sizeFactory == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
    }

    /// @notice Validates the parameters for the initialization
    /// @param owner The owner address
    /// @param f The fee configuration parameters
    /// @param r The risk configuration parameters
    /// @param o The oracle configuration parameters
    /// @param d The data configuration parameters
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

    /// @notice Executes the initialization of the fee configuration
    /// @param state The state
    /// @param f The fee configuration parameters
    function executeInitializeFeeConfig(State storage state, InitializeFeeConfigParams memory f) internal {
        state.feeConfig.swapFeeAPR = f.swapFeeAPR;
        state.feeConfig.fragmentationFee = f.fragmentationFee;

        state.feeConfig.liquidationRewardPercent = f.liquidationRewardPercent;
        state.feeConfig.overdueCollateralProtocolPercent = f.overdueCollateralProtocolPercent;
        state.feeConfig.collateralProtocolPercent = f.collateralProtocolPercent;

        state.feeConfig.feeRecipient = f.feeRecipient;
    }

    /// @notice Executes the initialization of the risk configuration
    /// @param state The state
    /// @param r The risk configuration parameters
    function executeInitializeRiskConfig(State storage state, InitializeRiskConfigParams memory r) internal {
        state.riskConfig.crOpening = r.crOpening;
        state.riskConfig.crLiquidation = r.crLiquidation;

        state.riskConfig.minimumCreditBorrowAToken = r.minimumCreditBorrowAToken;

        state.riskConfig.borrowATokenCap = r.borrowATokenCap;

        state.riskConfig.minTenor = r.minTenor;
        state.riskConfig.maxTenor = r.maxTenor;
    }

    /// @notice Executes the initialization of the oracle configuration
    /// @param state The state
    /// @param o The oracle configuration parameters
    function executeInitializeOracle(State storage state, InitializeOracleParams memory o) internal {
        state.oracle.priceFeed = IPriceFeed(o.priceFeed);
        state.oracle.variablePoolBorrowRateStaleRateInterval = o.variablePoolBorrowRateStaleRateInterval;
    }

    /// @notice Executes the initialization of the data configuration
    /// @param state The state
    /// @param d The data configuration parameters
    function executeInitializeData(State storage state, InitializeDataParams memory d) internal {
        state.data.nextDebtPositionId = DEBT_POSITION_ID_START;
        state.data.nextCreditPositionId = CREDIT_POSITION_ID_START;

        state.data.weth = IWETH(d.weth);
        state.data.underlyingCollateralToken = IERC20Metadata(d.underlyingCollateralToken);
        state.data.underlyingBorrowToken = IERC20Metadata(d.underlyingBorrowToken);
        state.data.variablePool = IPool(d.variablePool);

        state.data.collateralToken = new NonTransferrableToken(
            address(this),
            string.concat("Size ", IERC20Metadata(state.data.underlyingCollateralToken).name()),
            string.concat("sz", IERC20Metadata(state.data.underlyingCollateralToken).symbol()),
            IERC20Metadata(state.data.underlyingCollateralToken).decimals()
        );
        state.data.debtToken = new NonTransferrableToken(
            address(this),
            string.concat("Size Debt ", IERC20Metadata(state.data.underlyingBorrowToken).name()),
            string.concat("szDebt", IERC20Metadata(state.data.underlyingBorrowToken).symbol()),
            IERC20Metadata(state.data.underlyingBorrowToken).decimals()
        );
        state.data.borrowATokenV1_5 = NonTransferrableScaledTokenV1_5(d.borrowATokenV1_5);
        state.data.sizeFactory = ISizeFactory(d.sizeFactory);
    }

    /// @notice Executes the initialization of the protocol
    /// @param state The state
    /// @param f The fee configuration parameters
    /// @param r The risk configuration parameters
    /// @param o The oracle configuration parameters
    /// @param d The data configuration parameters
    function executeInitialize(
        State storage state,
        InitializeFeeConfigParams memory f,
        InitializeRiskConfigParams memory r,
        InitializeOracleParams memory o,
        InitializeDataParams memory d
    ) external {
        emit Events.Initialize(msg.sender);

        executeInitializeFeeConfig(state, f);
        executeInitializeRiskConfig(state, r);
        executeInitializeOracle(state, o);
        executeInitializeData(state, d);
    }
}
