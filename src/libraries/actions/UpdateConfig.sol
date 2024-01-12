// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Fixed, General, State} from "@src/SizeStorage.sol";

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
        General memory g = state.g;
        Fixed memory f = state.f;
        if (params.key == "priceFeed") {
            g.priceFeed = IPriceFeed(address(uint160(params.value)));
        } else if (params.key == "feeRecipient") {
            g.feeRecipient = address(uint160(params.value));
        } else if (params.key == "crOpening") {
            f.crOpening = params.value;
        } else if (params.key == "crLiquidation") {
            f.crLiquidation = params.value;
        } else if (params.key == "collateralPremiumToLiquidator") {
            f.collateralPremiumToLiquidator = params.value;
        } else if (params.key == "collateralPremiumToProtocol") {
            f.collateralPremiumToProtocol = params.value;
        } else if (params.key == "minimumCredit") {
            f.minimumCredit = params.value;
        } else {
            revert Errors.INVALID_KEY(params.key);
        }
        InitializeParams memory initializeParams = InitializeParams({
            owner: address(0),
            priceFeed: address(g.priceFeed),
            collateralAsset: address(g.collateralAsset),
            borrowAsset: address(g.borrowAsset),
            collateralToken: address(f.collateralToken),
            borrowToken: address(f.borrowToken),
            debtToken: address(f.debtToken),
            variablePool: address(g.variablePool),
            feeRecipient: address(g.feeRecipient)
        });
        InitializeExtraParams memory initializeExtraParams = InitializeExtraParams({
            crOpening: f.crOpening,
            crLiquidation: f.crLiquidation,
            collateralPremiumToLiquidator: f.collateralPremiumToLiquidator,
            collateralPremiumToProtocol: f.collateralPremiumToProtocol,
            minimumCredit: f.minimumCredit
        });
        state.validateInitialize(initializeParams, initializeExtraParams);
        state.executeInitialize(initializeParams, initializeExtraParams);
    }
}
