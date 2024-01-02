// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {UpdateConfig, UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct InitializeParams {
    address owner;
    address priceFeed;
    address collateralAsset;
    address borrowAsset;
    address collateralToken;
    address borrowToken;
    address debtToken;
    address protocolVault;
    address feeRecipient;
}

struct InitializeExtraParams {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 collateralPercentagePremiumToLiquidator;
    uint256 collateralPercentagePremiumToBorrower;
    uint256 minimumCredit;
}

library Initialize {
    using UpdateConfig for State;

    function validateInitialize(
        State storage state,
        InitializeParams memory params,
        InitializeExtraParams memory extraParams
    ) external view {
        // validate owner
        if (params.owner == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate price feed
        if (params.priceFeed == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate collateral asset
        if (params.collateralAsset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate borrow asset
        if (params.borrowAsset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate collateral token
        if (params.collateralToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate borrow token
        if (params.borrowToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate debt token
        if (params.debtToken == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate protocolVault
        if (params.protocolVault == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        state.validateUpdateConfig(
            UpdateConfigParams({
                feeRecipient: params.feeRecipient,
                crOpening: extraParams.crOpening,
                crLiquidation: extraParams.crLiquidation,
                collateralPercentagePremiumToLiquidator: extraParams.collateralPercentagePremiumToLiquidator,
                collateralPercentagePremiumToBorrower: extraParams.collateralPercentagePremiumToBorrower,
                minimumCredit: extraParams.minimumCredit
            })
        );
    }

    function executeInitialize(
        State storage state,
        InitializeParams memory params,
        InitializeExtraParams memory extraParams
    ) external {
        state.priceFeed = IPriceFeed(params.priceFeed);
        state.collateralAsset = IERC20Metadata(params.collateralAsset);
        state.borrowAsset = IERC20Metadata(params.borrowAsset);
        state.collateralToken = CollateralToken(params.collateralToken);
        state.borrowToken = BorrowToken(params.borrowToken);
        state.debtToken = DebtToken(params.debtToken);
        state.protocolVault = params.protocolVault;

        state.executeUpdateConfig(
            UpdateConfigParams({
                feeRecipient: params.feeRecipient,
                crOpening: extraParams.crOpening,
                crLiquidation: extraParams.crLiquidation,
                collateralPercentagePremiumToLiquidator: extraParams.collateralPercentagePremiumToLiquidator,
                collateralPercentagePremiumToBorrower: extraParams.collateralPercentagePremiumToBorrower,
                minimumCredit: extraParams.minimumCredit
            })
        );
    }
}
