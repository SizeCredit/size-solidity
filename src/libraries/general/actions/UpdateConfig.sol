// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Initialize} from "@src/libraries/general/actions/Initialize.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";

import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/general/actions/Initialize.sol";

struct UpdateConfigParams {
    string key;
    uint256 value;
}

/// @title UpdateConfig
/// @notice Contains the logic to update the configuration of the protocol
/// @dev The input validation is performed using the Initialize library
///      A `key` string is used to identify the configuration parameter to update and a `value` uint256 is used to set the new value
///      In case where an address is being updated, the `value` is converted to `uint160` and then to `address`
library UpdateConfig {
    using Initialize for State;

    function feeConfigParams(State storage state) public view returns (InitializeFeeConfigParams memory) {
        return InitializeFeeConfigParams({
            swapFeeAPR: state.feeConfig.swapFeeAPR,
            fragmentationFee: state.feeConfig.fragmentationFee,
            collateralLiquidatorPercent: state.feeConfig.collateralLiquidatorPercent,
            collateralProtocolPercent: state.feeConfig.collateralProtocolPercent,
            overdueLiquidatorReward: state.feeConfig.overdueLiquidatorReward,
            overdueColLiquidatorPercent: state.feeConfig.overdueColLiquidatorPercent,
            overdueColProtocolPercent: state.feeConfig.overdueColProtocolPercent,
            feeRecipient: state.feeConfig.feeRecipient
        });
    }

    function riskConfigParams(State storage state) public view returns (InitializeRiskConfigParams memory) {
        return InitializeRiskConfigParams({
            crOpening: state.riskConfig.crOpening,
            crLiquidation: state.riskConfig.crLiquidation,
            minimumCreditBorrowAToken: state.riskConfig.minimumCreditBorrowAToken,
            borrowATokenCap: state.riskConfig.borrowATokenCap,
            debtTokenCap: state.riskConfig.debtTokenCap,
            minimumMaturity: state.riskConfig.minimumMaturity
        });
    }

    function oracleParams(State storage state) public view returns (InitializeOracleParams memory) {
        return InitializeOracleParams({
            priceFeed: address(state.oracle.priceFeed),
            variablePoolBorrowRateFeed: address(state.oracle.variablePoolBorrowRateFeed)
        });
    }

    function dataParams(State storage state) external view returns (InitializeDataParams memory) {
        return InitializeDataParams({
            weth: address(state.data.weth),
            underlyingCollateralToken: address(state.data.underlyingCollateralToken),
            underlyingBorrowToken: address(state.data.underlyingBorrowToken),
            variablePool: address(state.data.variablePool)
        });
    }

    function validateUpdateConfig(State storage, UpdateConfigParams calldata) external pure {
        // validation is done at execution
    }

    function executeUpdateConfig(State storage state, UpdateConfigParams calldata params) external {
        if (Strings.equal(params.key, "crOpening")) {
            state.riskConfig.crOpening = params.value;
        } else if (Strings.equal(params.key, "crLiquidation")) {
            if (params.value >= state.riskConfig.crLiquidation) {
                revert Errors.INVALID_COLLATERAL_RATIO(params.value);
            }
            state.riskConfig.crLiquidation = params.value;
        } else if (Strings.equal(params.key, "minimumCreditBorrowAToken")) {
            state.riskConfig.minimumCreditBorrowAToken = params.value;
        } else if (Strings.equal(params.key, "borrowATokenCap")) {
            state.riskConfig.borrowATokenCap = params.value;
        } else if (Strings.equal(params.key, "debtTokenCap")) {
            state.riskConfig.debtTokenCap = params.value;
        } else if (Strings.equal(params.key, "minimumMaturity")) {
            state.riskConfig.minimumMaturity = params.value;
        } else if (Strings.equal(params.key, "swapFeeAPR")) {
            state.feeConfig.swapFeeAPR = params.value;
        } else if (Strings.equal(params.key, "fragmentationFee")) {
            state.feeConfig.fragmentationFee = params.value;
        } else if (Strings.equal(params.key, "collateralLiquidatorPercent")) {
            state.feeConfig.collateralLiquidatorPercent = params.value;
        } else if (Strings.equal(params.key, "collateralProtocolPercent")) {
            state.feeConfig.collateralProtocolPercent = params.value;
        } else if (Strings.equal(params.key, "overdueLiquidatorReward")) {
            state.feeConfig.overdueLiquidatorReward = params.value;
        } else if (Strings.equal(params.key, "overdueColLiquidatorPercent")) {
            state.feeConfig.overdueColLiquidatorPercent = params.value;
        } else if (Strings.equal(params.key, "overdueColProtocolPercent")) {
            state.feeConfig.overdueColProtocolPercent = params.value;
        } else if (Strings.equal(params.key, "feeRecipient")) {
            state.feeConfig.feeRecipient = address(uint160(params.value));
        } else if (Strings.equal(params.key, "priceFeed")) {
            state.oracle.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (Strings.equal(params.key, "variablePoolBorrowRateFeed")) {
            state.oracle.variablePoolBorrowRateFeed = IVariablePoolBorrowRateFeed(address(uint160(params.value)));
        } else {
            revert Errors.INVALID_KEY(params.key);
        }

        Initialize.validateInitializeFeeConfigParams(feeConfigParams(state));
        Initialize.validateInitializeRiskConfigParams(riskConfigParams(state));
        Initialize.validateInitializeOracleParams(oracleParams(state));

        emit Events.UpdateConfig(params.key, params.value);
    }
}
