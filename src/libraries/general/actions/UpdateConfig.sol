// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Initialize} from "@src/libraries/general/actions/Initialize.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/general/actions/Initialize.sol";

struct UpdateConfigParams {
    bytes32 key;
    uint256 value;
}

/// @title UpdateConfig
/// @notice Contains the logic to update the configuration of the protocol
/// @dev The input validation is performed using the Initialize library
///      A `key` bytes32 string is used to identify the configuration parameter to update and a `value` uint256 is used to set the new value
///      In case where an address is being updated, the `value` is converted to `uint160` and then to `address`
library UpdateConfig {
    using Initialize for State;

    function feeConfigParams(State storage state) public view returns (InitializeFeeConfigParams memory) {
        return InitializeFeeConfigParams({
            repayFeeAPR: state.feeConfig.repayFeeAPR,
            earlyLenderExitFee: state.feeConfig.earlyLenderExitFee,
            earlyBorrowerExitFee: state.feeConfig.earlyBorrowerExitFee,
            collateralOverdueTransferFee: state.feeConfig.collateralOverdueTransferFee,
            feeRecipient: state.feeConfig.feeRecipient
        });
    }

    function riskConfigParams(State storage state) public view returns (InitializeRiskConfigParams memory) {
        return InitializeRiskConfigParams({
            crOpening: state.riskConfig.crOpening,
            crLiquidation: state.riskConfig.crLiquidation,
            minimumCreditBorrowAToken: state.riskConfig.minimumCreditBorrowAToken,
            collateralSplitLiquidatorPercent: state.riskConfig.collateralSplitLiquidatorPercent,
            collateralSplitProtocolPercent: state.riskConfig.collateralSplitProtocolPercent,
            collateralTokenCap: state.riskConfig.collateralTokenCap,
            borrowATokenCap: state.riskConfig.borrowATokenCap,
            debtTokenCap: state.riskConfig.debtTokenCap,
            moveToVariablePoolHFThreshold: state.riskConfig.moveToVariablePoolHFThreshold
        });
    }

    function oracleParams(State storage state) public view returns (InitializeOracleParams memory) {
        return InitializeOracleParams({
            priceFeed: address(state.oracle.priceFeed),
            marketBorrowRateFeed: address(state.oracle.marketBorrowRateFeed)
        });
    }

    function dataParams(State storage state) public view returns (InitializeDataParams memory) {
        return InitializeDataParams({
            underlyingCollateralToken: address(state.data.underlyingCollateralToken),
            underlyingBorrowToken: address(state.data.underlyingBorrowToken),
            variablePool: address(state.data.variablePool)
        });
    }

    function validateUpdateConfig(State storage, UpdateConfigParams calldata) external pure {
        // validation is done at execution
    }

    function executeUpdateConfig(State storage state, UpdateConfigParams calldata params) external {
        if (params.key == "crOpening") {
            state.riskConfig.crOpening = params.value;
        } else if (params.key == "crLiquidation") {
            state.riskConfig.crLiquidation = params.value;
        } else if (params.key == "minimumCreditBorrowAToken") {
            state.riskConfig.minimumCreditBorrowAToken = params.value;
        } else if (params.key == "collateralSplitLiquidatorPercent") {
            state.riskConfig.collateralSplitLiquidatorPercent = params.value;
        } else if (params.key == "collateralSplitProtocolPercent") {
            state.riskConfig.collateralSplitProtocolPercent = params.value;
        } else if (params.key == "collateralTokenCap") {
            state.riskConfig.collateralTokenCap = params.value;
        } else if (params.key == "borrowATokenCap") {
            state.riskConfig.borrowATokenCap = params.value;
        } else if (params.key == "debtTokenCap") {
            state.riskConfig.debtTokenCap = params.value;
        } else if (params.key == "moveToVariablePoolHFThreshold") {
            state.riskConfig.moveToVariablePoolHFThreshold = params.value;
        } else if (params.key == "repayFeeAPR") {
            state.feeConfig.repayFeeAPR = params.value;
        } else if (params.key == "earlyLenderExitFee") {
            state.feeConfig.earlyLenderExitFee = params.value;
        } else if (params.key == "earlyBorrowerExitFee") {
            state.feeConfig.earlyBorrowerExitFee = params.value;
        } else if (params.key == "collateralOverdueTransferFee") {
            state.feeConfig.collateralOverdueTransferFee = params.value;
        } else if (params.key == "feeRecipient") {
            state.feeConfig.feeRecipient = address(uint160(params.value));
        } else if (params.key == "priceFeed") {
            state.oracle.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (params.key == "marketBorrowRateFeed") {
            state.oracle.marketBorrowRateFeed = IMarketBorrowRateFeed(address(uint160(params.value)));
        } else {
            revert Errors.INVALID_KEY(params.key);
        }

        Initialize.validateInitializeFeeConfigParams(feeConfigParams(state));
        Initialize.validateInitializeRiskConfigParams(riskConfigParams(state));
        Initialize.validateInitializeOracleParams(oracleParams(state));

        emit Events.UpdateConfig(params.key, params.value);
    }
}
