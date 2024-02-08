// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Initialize} from "@src/libraries/general/actions/Initialize.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {
    InitializeConfigParams,
    InitializeDataParams,
    InitializeOracleParams
} from "@src/libraries/general/actions/Initialize.sol";

struct UpdateConfigParams {
    bytes32 key;
    uint256 value;
}

library UpdateConfig {
    using Initialize for State;

    function configParams(State storage state) public view returns (InitializeConfigParams memory) {
        return InitializeConfigParams({
            crOpening: state.config.crOpening,
            crLiquidation: state.config.crLiquidation,
            minimumCreditBorrowAToken: state.config.minimumCreditBorrowAToken,
            collateralSplitLiquidatorPercent: state.config.collateralSplitLiquidatorPercent,
            collateralSplitProtocolPercent: state.config.collateralSplitProtocolPercent,
            collateralTokenCap: state.config.collateralTokenCap,
            borrowATokenCap: state.config.borrowATokenCap,
            debtTokenCap: state.config.debtTokenCap,
            repayFeeAPR: state.config.repayFeeAPR,
            earlyLenderExitFee: state.config.earlyLenderExitFee,
            earlyBorrowerExitFee: state.config.earlyBorrowerExitFee,
            collateralOverdueTransferFee: state.config.collateralOverdueTransferFee,
            feeRecipient: state.config.feeRecipient
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

    function validateUpdateConfig(State storage, UpdateConfigParams memory) external pure {
        // validation is done at execution
    }

    function executeUpdateConfig(State storage state, UpdateConfigParams memory params) external {
        if (params.key == "crOpening") {
            state.config.crOpening = params.value;
        } else if (params.key == "crLiquidation") {
            state.config.crLiquidation = params.value;
        } else if (params.key == "minimumCreditBorrowAToken") {
            state.config.minimumCreditBorrowAToken = params.value;
        } else if (params.key == "collateralSplitLiquidatorPercent") {
            state.config.collateralSplitLiquidatorPercent = params.value;
        } else if (params.key == "collateralSplitProtocolPercent") {
            state.config.collateralSplitProtocolPercent = params.value;
        } else if (params.key == "collateralTokenCap") {
            state.config.collateralTokenCap = params.value;
        } else if (params.key == "borrowATokenCap") {
            state.config.borrowATokenCap = params.value;
        } else if (params.key == "debtTokenCap") {
            state.config.debtTokenCap = params.value;
        } else if (params.key == "repayFeeAPR") {
            state.config.repayFeeAPR = params.value;
        } else if (params.key == "earlyLenderExitFee") {
            state.config.earlyLenderExitFee = params.value;
        } else if (params.key == "earlyBorrowerExitFee") {
            state.config.earlyBorrowerExitFee = params.value;
        } else if (params.key == "collateralOverdueTransferFee") {
            state.config.collateralOverdueTransferFee = params.value;
        } else if (params.key == "feeRecipient") {
            state.config.feeRecipient = address(uint160(params.value));
        } else if (params.key == "priceFeed") {
            state.oracle.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (params.key == "marketBorrowRateFeed") {
            state.oracle.marketBorrowRateFeed = IMarketBorrowRateFeed(address(uint160(params.value)));
        } else {
            revert Errors.INVALID_KEY(params.key);
        }

        Initialize.validateInitializeConfigParams(configParams(state));
        Initialize.validateInitializeOracleParams(oracleParams(state));

        emit Events.UpdateConfig(params.key, params.value);
    }
}
