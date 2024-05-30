// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {State} from "@src/core/SizeStorage.sol";
import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";

import {Math, PERCENT} from "@src/core/libraries/Math.sol";
import {Initialize} from "@src/core/libraries/general/actions/Initialize.sol";

import {IPriceFeed} from "@src/core/oracle/IPriceFeed.sol";

import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/core/libraries/general/actions/Initialize.sol";

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
            liquidationRewardPercent: state.feeConfig.liquidationRewardPercent,
            overdueCollateralProtocolPercent: state.feeConfig.overdueCollateralProtocolPercent,
            collateralProtocolPercent: state.feeConfig.collateralProtocolPercent,
            feeRecipient: state.feeConfig.feeRecipient
        });
    }

    function riskConfigParams(State storage state) public view returns (InitializeRiskConfigParams memory) {
        return InitializeRiskConfigParams({
            crOpening: state.riskConfig.crOpening,
            crLiquidation: state.riskConfig.crLiquidation,
            minimumCreditBorrowAToken: state.riskConfig.minimumCreditBorrowAToken,
            borrowATokenCap: state.riskConfig.borrowATokenCap,
            minimumTenor: state.riskConfig.minimumTenor,
            maximumTenor: state.riskConfig.maximumTenor
        });
    }

    function oracleParams(State storage state) public view returns (InitializeOracleParams memory) {
        return InitializeOracleParams({
            priceFeed: address(state.oracle.priceFeed),
            variablePoolBorrowRateStaleRateInterval: state.oracle.variablePoolBorrowRateStaleRateInterval
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
        } else if (Strings.equal(params.key, "minimumTenor")) {
            state.riskConfig.minimumTenor = params.value;
        } else if (Strings.equal(params.key, "maximumTenor")) {
            if (params.value >= Math.mulDivDown(PERCENT, 365 days, state.feeConfig.swapFeeAPR)) {
                revert Errors.VALUE_GREATER_THAN_MAX(
                    params.value, Math.mulDivDown(PERCENT, 365 days, state.feeConfig.swapFeeAPR)
                );
            }
            state.riskConfig.maximumTenor = params.value;
        } else if (Strings.equal(params.key, "swapFeeAPR")) {
            if (params.value >= Math.mulDivDown(state.riskConfig.minimumTenor, PERCENT, 365 days)) {
                revert Errors.VALUE_GREATER_THAN_MAX(
                    params.value, Math.mulDivDown(state.riskConfig.minimumTenor, PERCENT, 365 days)
                );
            }
            state.feeConfig.swapFeeAPR = params.value;
        } else if (Strings.equal(params.key, "fragmentationFee")) {
            state.feeConfig.fragmentationFee = params.value;
        } else if (Strings.equal(params.key, "liquidationRewardPercent")) {
            state.feeConfig.liquidationRewardPercent = params.value;
        } else if (Strings.equal(params.key, "overdueCollateralProtocolPercent")) {
            state.feeConfig.overdueCollateralProtocolPercent = params.value;
        } else if (Strings.equal(params.key, "collateralProtocolPercent")) {
            state.feeConfig.collateralProtocolPercent = params.value;
        } else if (Strings.equal(params.key, "feeRecipient")) {
            state.feeConfig.feeRecipient = address(uint160(params.value));
        } else if (Strings.equal(params.key, "priceFeed")) {
            state.oracle.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (Strings.equal(params.key, "variablePoolBorrowRateStaleRateInterval")) {
            state.oracle.variablePoolBorrowRateStaleRateInterval = uint64(params.value);
        } else {
            revert Errors.INVALID_KEY(params.key);
        }

        Initialize.validateInitializeFeeConfigParams(feeConfigParams(state));
        Initialize.validateInitializeRiskConfigParams(riskConfigParams(state));
        Initialize.validateInitializeOracleParams(oracleParams(state));

        emit Events.UpdateConfig(params.key, params.value);
    }
}
