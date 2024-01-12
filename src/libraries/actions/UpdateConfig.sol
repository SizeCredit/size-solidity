// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Config, State, Tokens} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Initialize, InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

struct UpdateConfigParams {
    bytes32 key;
    uint256 value;
}

library UpdateConfig {
    using Initialize for State;

    function validateUpdateConfig(State storage, UpdateConfigParams memory params) external pure {
        // validation is done at execution
    }

    function executeUpdateConfig(State storage state, UpdateConfigParams memory params) external {
        Config memory config = state.config;
        Tokens memory tokens = state.tokens;
        if (params.key == "priceFeed") {
            config.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (params.key == "feeRecipient") {
            config.feeRecipient = address(uint160(params.value));
        } else if (params.key == "crOpening") {
            config.crOpening = params.value;
        } else if (params.key == "crLiquidation") {
            config.crLiquidation = params.value;
        } else if (params.key == "collateralPremiumToLiquidator") {
            config.collateralPremiumToLiquidator = params.value;
        } else if (params.key == "collateralPremiumToProtocol") {
            config.collateralPremiumToProtocol = params.value;
        } else if (params.key == "minimumCredit") {
            config.minimumCredit = params.value;
        } else {
            revert Errors.INVALID_KEY(params.key);
        }
        InitializeParams memory initializeParams = InitializeParams({
            owner: address(0),
            priceFeed: address(config.priceFeed),
            collateralAsset: address(tokens.collateralAsset),
            borrowAsset: address(tokens.borrowAsset),
            collateralToken: address(tokens.collateralToken),
            borrowToken: address(tokens.borrowToken),
            debtToken: address(tokens.debtToken),
            variablePool: address(config.variablePool),
            feeRecipient: address(config.feeRecipient)
        });
        InitializeExtraParams memory initializeExtraParams = InitializeExtraParams({
            crOpening: config.crOpening,
            crLiquidation: config.crLiquidation,
            collateralPremiumToLiquidator: config.collateralPremiumToLiquidator,
            collateralPremiumToProtocol: config.collateralPremiumToProtocol,
            minimumCredit: config.minimumCredit
        });
        state.validateInitialize(initializeParams, initializeExtraParams);
        state.executeInitialize(initializeParams, initializeExtraParams);
    }
}
