// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Size} from "@src/Size.sol";
import {UserView} from "@src/SizeView.sol";
import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary
} from "@src/libraries/LoanLibrary.sol";
import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {console2 as console} from "forge-std/console2.sol";

abstract contract Logger {
    using LoanLibrary for DebtPosition;
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;

    function _log(UserView memory userView) internal pure {
        console.log("account", userView.account);
        if (!userView.user.loanOffer.isNull()) {
            console.log("user.loanOffer.maxDueDate", userView.user.loanOffer.maxDueDate);
            for (uint256 i = 0; i < userView.user.loanOffer.curveRelativeTime.aprs.length; i++) {
                console.log(
                    "user.loanOffer.curveRelativeTime.tenors[]", userView.user.loanOffer.curveRelativeTime.tenors[i]
                );
                console.log(
                    "user.loanOffer.curveRelativeTime.aprs[]", userView.user.loanOffer.curveRelativeTime.aprs[i]
                );
                console.log(
                    "user.loanOffer.curveRelativeTime.marketRateMultipliers[]",
                    userView.user.loanOffer.curveRelativeTime.marketRateMultipliers[i]
                );
            }
        }
        if (!userView.user.borrowOffer.isNull()) {
            for (uint256 i = 0; i < userView.user.borrowOffer.curveRelativeTime.aprs.length; i++) {
                console.log(
                    "user.borrowOffer.curveRelativeTime.tenors[]", userView.user.borrowOffer.curveRelativeTime.tenors[i]
                );
                console.log(
                    "user.borrowOffer.curveRelativeTime.aprs[]", userView.user.borrowOffer.curveRelativeTime.aprs[i]
                );
                console.log(
                    "user.borrowOffer.curveRelativeTime.marketRateMultipliers[]",
                    userView.user.borrowOffer.curveRelativeTime.marketRateMultipliers[i]
                );
            }
        }
        console.log("collateralBalance", userView.collateralTokenBalance);
        console.log("borrowATokenBalance", userView.borrowATokenBalance);
        console.log("debtBalance", userView.debtBalance);
    }

    function _log(DebtPosition memory debtPosition) internal pure {
        console.log("borrower", debtPosition.borrower);
        console.log("futureValue", debtPosition.futureValue);
        console.log("dueDate", debtPosition.dueDate);
        console.log("liquidityIndexAtRepayment", debtPosition.liquidityIndexAtRepayment);
    }

    function _log(CreditPosition memory creditPosition) internal pure {
        console.log("lender", creditPosition.lender);
        console.log("forSale", creditPosition.forSale);
        console.log("credit", creditPosition.credit);
        console.log("debtPositionId", creditPosition.debtPositionId);
    }

    function _log(Size size) internal view {
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        uint256 totalDebt;
        uint256 totalCredit;
        for (uint256 i = 0; i < debtPositionsCount; ++i) {
            uint256 debtPositionId = DEBT_POSITION_ID_START + i;
            totalDebt += size.getDebtPosition(debtPositionId).futureValue;
            console.log(string.concat("D[", Strings.toString(i), "]"), size.getDebtPosition(debtPositionId).futureValue);
        }
        console.log("D   ", totalDebt);
        for (uint256 i = 0; i < creditPositionsCount; ++i) {
            uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
            totalCredit += size.getCreditPosition(creditPositionId).credit;
            console.log(string.concat("C[", Strings.toString(i), "]"), size.getCreditPosition(creditPositionId).credit);
        }
        console.log("C   ", totalCredit);
    }
}
