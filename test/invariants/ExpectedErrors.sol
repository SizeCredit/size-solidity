// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Deploy} from "@script/Deploy.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Properties} from "@test/invariants/Properties.sol";

abstract contract ExpectedErrors is Deploy, Properties {
    bool internal success;
    bytes internal returnData;

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

    constructor() {
        // DEPOSIT_ERRORS
        DEPOSIT_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        DEPOSIT_ERRORS.push(Errors.INVALID_TOKEN.selector);
        DEPOSIT_ERRORS.push(Errors.NULL_AMOUNT.selector);
        DEPOSIT_ERRORS.push(Errors.NULL_ADDRESS.selector);
        DEPOSIT_ERRORS.push(Errors.BORROW_ATOKEN_CAP_EXCEEDED.selector);

        // WITHDRAW_ERRORS
        WITHDRAW_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        WITHDRAW_ERRORS.push(Errors.NULL_AMOUNT.selector);
        WITHDRAW_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);

        // SELL_CREDIT_MARKET_ERRORS
        SELL_CREDIT_MARKET_ERRORS.push(Errors.INVALID_CREDIT_POSITION_ID.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.INVALID_LOAN_OFFER.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NULL_AMOUNT.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.BORROWER_IS_NOT_LENDER.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CASH.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CREDIT.selector);
        SELL_CREDIT_MARKET_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.STALE_RATE.selector);
        SELL_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector);

        // SELL_CREDIT_LIMIT_ERRORS
        SELL_CREDIT_LIMIT_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);

        // BUY_CREDIT_MARKET_ERRORS
        BUY_CREDIT_MARKET_ERRORS.push(Errors.INVALID_BORROW_OFFER.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CASH.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.NOT_ENOUGH_CREDIT.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.CREDIT_NOT_FOR_SALE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(Errors.STALE_RATE.selector);
        BUY_CREDIT_MARKET_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);

        // BUY_CREDIT_LIMIT_ERRORS
        BUY_CREDIT_LIMIT_ERRORS.push(Errors.PAST_MAX_DUE_DATE.selector);
        BUY_CREDIT_LIMIT_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);

        // REPAY_ERRORS
        REPAY_ERRORS.push(Errors.LOAN_ALREADY_REPAID.selector);
        REPAY_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);

        // CLAIM_ERRORS
        CLAIM_ERRORS.push(Errors.LOAN_NOT_REPAID.selector);
        CLAIM_ERRORS.push(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector);

        // LIQUIDATE_ERRORS
        LIQUIDATE_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);
        LIQUIDATE_ERRORS.push(Errors.LOAN_NOT_LIQUIDATABLE.selector);
        LIQUIDATE_ERRORS.push(Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT.selector);

        // SELF_LIQUIDATE_ERRORS
        SELF_LIQUIDATE_ERRORS.push(Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector);
        SELF_LIQUIDATE_ERRORS.push(Errors.LIQUIDATION_NOT_AT_LOSS.selector);
        SELF_LIQUIDATE_ERRORS.push(Errors.LIQUIDATOR_IS_NOT_LENDER.selector);

        // LIQUIDATE_WITH_REPLACEMENT_ERRORS
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(IAccessControl.AccessControlUnauthorizedAccount.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.LOAN_NOT_LIQUIDATABLE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.LIQUIDATE_PROFIT_BELOW_MINIMUM_COLLATERAL_PROFIT.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.LOAN_NOT_ACTIVE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.INVALID_BORROW_OFFER.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(Errors.STALE_RATE.selector);
        LIQUIDATE_WITH_REPLACEMENT_ERRORS.push(IERC20Errors.ERC20InsufficientBalance.selector);

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
        COMPENSATE_ERRORS.push(Errors.USER_IS_UNDERWATER.selector);
        COMPENSATE_ERRORS.push(Errors.TENOR_OUT_OF_RANGE.selector);

        // SET_USER_CONFIGURATION_ERRORS N/A
    }

    modifier checkExpectedErrors(bytes4[] storage errors) {
        success = false;
        returnData = bytes("");

        _;

        if (!success) {
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (errors[i] == bytes4(returnData)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }
}
