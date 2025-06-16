// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ERC4626 as ERC4626OpenZeppelin} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {Deploy} from "@script/Deploy.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";
import {console} from "forge-std/console.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Properties} from "@test/invariants/Properties.sol";

import {ERC4626 as ERC4626OpenZeppelin} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC4626 as ERC4626Solady} from "@solady/src/tokens/ERC4626.sol";

abstract contract ExpectedErrors is Deploy, Properties {
    bytes4[] internal DEPOSIT_ERRORS;
    bytes4[] internal WITHDRAW_ERRORS;
    bytes4[] internal SELL_CREDIT_MARKET_ERRORS;
    bytes4[] internal SELL_CREDIT_LIMIT_ERRORS;
    bytes4[] internal BUY_CREDIT_MARKET_ERRORS;
    bytes4[] internal BUY_CREDIT_LIMIT_ERRORS;
    bytes4[] internal BORROWER_EXIT_ERRORS;
    bytes4[] internal REPAY_ERRORS;
    bytes4[] internal CLAIM_ERRORS;
    bytes4[] internal LIQUIDATE_ERRORS;
    bytes4[] internal SELF_LIQUIDATE_ERRORS;
    bytes4[] internal LIQUIDATE_WITH_REPLACEMENT_ERRORS;
    bytes4[] internal COMPENSATE_ERRORS;
    bytes4[] internal SET_USER_CONFIGURATION_ERRORS;
    bytes4[] internal SET_COPY_LIMIT_ORDER_CONFIGS_ERRORS;
    bytes4[] internal PARTIAL_REPAY_ERRORS;
    bytes4[] internal SET_VAULT_ERRORS;

    bytes4[] internal VAULT_ERRORS;

    constructor() {
        // VAULT_ERRORS
        VAULT_ERRORS.push(ERC4626Solady.WithdrawMoreThanMax.selector);
        VAULT_ERRORS.push(ERC4626OpenZeppelin.ERC4626ExceededMaxWithdraw.selector);
        VAULT_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        VAULT_ERRORS.push(bytes4(keccak256("Error(string)"))); // ZERO_ASSETS / ZERO_SHARES from ERC4626Solmate
        VAULT_ERRORS.push(IAdapter.InsufficientAssets.selector);

        // DEPOSIT_ERRORS
        DEPOSIT_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        DEPOSIT_ERRORS.push(Errors.INVALID_TOKEN.selector);
        DEPOSIT_ERRORS.push(Errors.NULL_AMOUNT.selector);
        DEPOSIT_ERRORS.push(Errors.NULL_ADDRESS.selector);

        // WITHDRAW_ERRORS
        WITHDRAW_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        WITHDRAW_ERRORS.push(Errors.NULL_AMOUNT.selector);
        WITHDRAW_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);

        // SELL_CREDIT_MARKET_ERRORS
        SELL_CREDIT_MARKET_ERRORS.push(Errors.INVALID_CREDIT_POSITION_ID.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.INVALID_OFFER.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NULL_AMOUNT.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.BORROWER_IS_NOT_LENDER.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CASH.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CREDIT.selector);
        SELL_CREDIT_MARKET_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.STALE_RATE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.INVERTED_CURVES.selector);
        SELL_CREDIT_MARKET_ERRORS.push(SafeCast.SafeCastOverflowedIntToUint.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            SELL_CREDIT_MARKET_ERRORS.push(VAULT_ERRORS[i]);
        }

        // SELL_CREDIT_LIMIT_ERRORS
        SELL_CREDIT_LIMIT_ERRORS.push(Errors.PAST_MAX_DUE_DATE.selector);
        SELL_CREDIT_LIMIT_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);

        // BUY_CREDIT_MARKET_ERRORS
        BUY_CREDIT_MARKET_ERRORS.push(Errors.INVALID_OFFER.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CASH.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.NULL_AMOUNT.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CREDIT.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_NOT_FOR_SALE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.STALE_RATE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.INVERTED_CURVES.selector);
        BUY_CREDIT_MARKET_ERRORS.push(SafeCast.SafeCastOverflowedIntToUint.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            BUY_CREDIT_MARKET_ERRORS.push(VAULT_ERRORS[i]);
        }

        // BUY_CREDIT_LIMIT_ERRORS
        BUY_CREDIT_LIMIT_ERRORS.push(Errors.PAST_MAX_DUE_DATE.selector);
        BUY_CREDIT_LIMIT_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);

        // REPAY_ERRORS
        REPAY_ERRORS.push(Errors.LOAN_ALREADY_REPAID.selector);
        REPAY_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            REPAY_ERRORS.push(VAULT_ERRORS[i]);
        }

        // CLAIM_ERRORS
        CLAIM_ERRORS.push(Errors.LOAN_NOT_REPAID.selector);
        CLAIM_ERRORS.push(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector);

        // LIQUIDATE_ERRORS
        LIQUIDATE_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        LIQUIDATE_ERRORS.push(Errors.LOAN_NOT_LIQUIDATABLE.selector);
        LIQUIDATE_ERRORS.push(Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            LIQUIDATE_ERRORS.push(VAULT_ERRORS[i]);
        }

        // SELF_LIQUIDATE_ERRORS
        SELF_LIQUIDATE_ERRORS.push(Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector);
        SELF_LIQUIDATE_ERRORS.push(Errors.LIQUIDATOR_IS_NOT_LENDER.selector);

        // LIQUIDATE_WITH_REPLACEMENT_ERRORS
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(IAccessControl.AccessControlUnauthorizedAccount.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.LOAN_NOT_LIQUIDATABLE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.LOAN_NOT_ACTIVE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.INVALID_OFFER.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.STALE_RATE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.INVERTED_CURVES.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(SafeCast.SafeCastOverflowedIntToUint.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(VAULT_ERRORS[i]);
        }

        // COMPENSATE_ERRORS
        COMPENSATE_ERRORS.push(Errors.LOAN_ALREADY_REPAID.selector);
        COMPENSATE_ERRORS.push(Errors.LOAN_NOT_ACTIVE.selector);
        COMPENSATE_ERRORS.push(Errors.DUE_DATE_NOT_COMPATIBLE.selector);
        COMPENSATE_ERRORS.push(Errors.INVALID_LENDER.selector);
        COMPENSATE_ERRORS.push(Errors.COMPENSATOR_IS_NOT_BORROWER.selector);
        COMPENSATE_ERRORS.push(Errors.NULL_AMOUNT.selector);
        COMPENSATE_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        COMPENSATE_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector);
        COMPENSATE_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector);
        COMPENSATE_ERRORS.push(Errors.INVALID_CREDIT_POSITION_ID.selector);
        COMPENSATE_ERRORS.push(Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector);
        COMPENSATE_ERRORS.push(Errors.MUST_IMPROVE_COLLATERAL_RATIO.selector);

        // SET_USER_CONFIGURATION_ERRORS N/A

        // SET_COPY_LIMIT_ORDER_CONFIGS_ERRORS
        SET_COPY_LIMIT_ORDER_CONFIGS_ERRORS.push(Errors.INVALID_APR_RANGE.selector);
        SET_COPY_LIMIT_ORDER_CONFIGS_ERRORS.push(Errors.INVALID_TENOR_RANGE.selector);
        SET_COPY_LIMIT_ORDER_CONFIGS_ERRORS.push(Errors.INVALID_ADDRESS.selector);
        SET_COPY_LIMIT_ORDER_CONFIGS_ERRORS.push(Errors.NULL_ADDRESS.selector);

        // PARTIAL_REPAY_ERRORS
        PARTIAL_REPAY_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        PARTIAL_REPAY_ERRORS.push(Errors.INVALID_CREDIT_POSITION_ID.selector);
        PARTIAL_REPAY_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector);
        PARTIAL_REPAY_ERRORS.push(Errors.LOAN_ALREADY_REPAID.selector);
        PARTIAL_REPAY_ERRORS.push(Errors.NULL_AMOUNT.selector);
        PARTIAL_REPAY_ERRORS.push(Errors.INVALID_AMOUNT.selector);
        PARTIAL_REPAY_ERRORS.push(Errors.INVALID_BORROWER.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            PARTIAL_REPAY_ERRORS.push(VAULT_ERRORS[i]);
        }

        // SET_VAULT_ERRORS
        SET_VAULT_ERRORS.push(Errors.INVALID_VAULT.selector);
        for (uint256 i = 0; i < VAULT_ERRORS.length; i++) {
            SET_VAULT_ERRORS.push(VAULT_ERRORS[i]);
        }
    }

    modifier checkExpectedErrors(bytes4[] storage errors) {
        success = false;
        returnData = bytes("");

        _;

        if (!success) {
            bool expected = false;
            console.logBytes(returnData);
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(returnData)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }

        success = false;
        returnData = bytes("");
    }
}
