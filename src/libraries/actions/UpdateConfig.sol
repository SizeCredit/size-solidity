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
        if (params.key == "feeRecipient") {
            state._general.feeRecipient = address(uint160(params.value));
        } else if (params.key == "minimumCredit") {
            state._fixed.minimumCredit = params.value;
        } else {
            revert Errors.INVALID_KEY(params.key);
        }
        InitializeParams memory initializeParams = InitializeParams({
            owner: address(0),
            priceFeed: address(state._general.priceFeed),
            collateralAsset: address(state._general.collateralAsset),
            borrowAsset: address(state._general.borrowAsset),
            collateralToken: address(state._fixed.collateralToken),
            borrowToken: address(state._fixed.borrowToken),
            debtToken: address(state._fixed.debtToken),
            variablePool: address(state._general.variablePool),
            feeRecipient: address(state._general.feeRecipient)
        });
        InitializeExtraParams memory initializeExtraParams = InitializeExtraParams({
            crOpening: state._fixed.crOpening,
            crLiquidation: state._fixed.crLiquidation,
            collateralPremiumToLiquidator: state._fixed.collateralPremiumToLiquidator,
            collateralPremiumToProtocol: state._fixed.collateralPremiumToProtocol,
            minimumCredit: state._fixed.minimumCredit
        });
        state.validateInitialize(initializeParams, initializeExtraParams);
    }
}
