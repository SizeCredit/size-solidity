// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/Math.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateFixedLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
}

library LiquidateFixedLoan {
    using VariableLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;

    function validateLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender
        if (state.borrowATokenBalanceOf(msg.sender) < loan.getDebt()) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowATokenBalanceOf(msg.sender), loan.getDebt());
        }

        // validate loanId
        if (!state.isLoanLiquidatable(params.loanId)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.borrower), state.getFixedLoanStatus(loan)
            );
        }
        // TODO: deal with overdue loans
        if (state.getFixedLoanStatus(loan) != FixedLoanStatus.ACTIVE) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.borrower), state.getFixedLoanStatus(loan)
            );
        }

        // validate minimumCollateralRatio
        if (state.collateralRatio(loan.borrower) < params.minimumCollateralRatio) {
            revert Errors.COLLATERAL_RATIO_BELOW_MINIMUM_COLLATERAL_RATIO(
                state.collateralRatio(loan.borrower), params.minimumCollateralRatio
            );
        }
    }

    function executeLiquidateFixedLoan(State storage state, LiquidateFixedLoanParams calldata params)
        external
        returns (uint256)
    {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        uint256 assignedCollateral = state.getFOLAssignedCollateral(loan);
        uint256 debtBorrowTokenWad =
            ConversionLibrary.amountToWad(loan.getDebt(), state._general.borrowAsset.decimals());
        uint256 debtInCollateralToken = Math.mulDivDown(
            debtBorrowTokenWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice()
        );
        FixedLoanStatus loanStatus = state.getFixedLoanStatus(loan);

        emit Events.LiquidateFixedLoan(
            params.loanId, params.minimumCollateralRatio, assignedCollateral, debtInCollateralToken, loanStatus
        );

        uint256 liquidatorProfitCollateralToken;

        // TODO
        if (loanStatus == FixedLoanStatus.OVERDUE) {} else { // is FixedLoanStatus.ACTIVE as per validateLiquidateFixedLoan
        }

        if (assignedCollateral > debtInCollateralToken) {
            // split remaining collateral between liquidator and protocol
            uint256 collateralRemainder = assignedCollateral - debtInCollateralToken;

            uint256 collateralRemainderToLiquidator =
                Math.mulDivDown(collateralRemainder, state._fixed.collateralPremiumToLiquidator, PERCENT);
            uint256 collateralRemainderToProtocol =
                Math.mulDivDown(collateralRemainder, state._fixed.collateralPremiumToProtocol, PERCENT);

            liquidatorProfitCollateralToken = debtInCollateralToken + collateralRemainderToLiquidator;
            state._fixed.collateralToken.transferFrom(
                loan.borrower, state._general.feeRecipient, collateralRemainderToProtocol
            );
        } else {
            // unprofitable liquidation
            liquidatorProfitCollateralToken = assignedCollateral;
        }

        state._fixed.collateralToken.transferFrom(loan.borrower, msg.sender, liquidatorProfitCollateralToken);
        state.transferBorrowAToken(msg.sender, address(this), loan.getDebt());
        state._fixed.debtToken.burn(loan.borrower, loan.getDebt());
        loan.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        loan.repaid = true;

        return liquidatorProfitCollateralToken;
    }
}
