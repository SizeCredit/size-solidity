// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {State} from "@src/SizeStorage.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/libraries/LoanLibrary.sol";

contract SizeMock is Size {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;

    // https://github.com/foundry-rs/foundry/issues/4615
    bool public IS_TEST = true;

    function version() public pure returns (uint256) {
        return 2;
    }

    function getDebtPositions() external view returns (DebtPosition[] memory debtPositions) {
        uint256 length = state.data.nextDebtPositionId - DEBT_POSITION_ID_START;
        debtPositions = new DebtPosition[](length);
        for (uint256 i = 0; i < length; ++i) {
            uint256 debtPositionId = DEBT_POSITION_ID_START + i;
            debtPositions[i] = state.getDebtPosition(debtPositionId);
        }
    }

    function getDebtPositions(uint256[] memory debtPositionIds)
        external
        view
        returns (DebtPosition[] memory debtPositions)
    {
        uint256 length = debtPositionIds.length;
        debtPositions = new DebtPosition[](length);
        for (uint256 i = 0; i < length; ++i) {
            debtPositions[i] = state.getDebtPosition(debtPositionIds[i]);
        }
    }

    function getCreditPositions() external view returns (CreditPosition[] memory creditPositions) {
        uint256 length = state.data.nextCreditPositionId - CREDIT_POSITION_ID_START;
        creditPositions = new CreditPosition[](length);
        for (uint256 i = 0; i < length; ++i) {
            uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
            creditPositions[i] = state.getCreditPosition(creditPositionId);
        }
    }

    function getCreditPositions(uint256[] memory creditPositionIds)
        public
        view
        returns (CreditPosition[] memory creditPositions)
    {
        uint256 length = creditPositionIds.length;
        creditPositions = new CreditPosition[](length);
        for (uint256 i = 0; i < length; ++i) {
            creditPositions[i] = state.getCreditPosition(creditPositionIds[i]);
        }
    }

    function getCreditPositionIdsByDebtPositionId(uint256 debtPositionId)
        public
        view
        returns (uint256[] memory creditPositionIds)
    {
        uint256 length = state.data.nextCreditPositionId - CREDIT_POSITION_ID_START;
        creditPositionIds = new uint256[](length);
        uint256 numberOfCreditPositions = 0;
        for (uint256 i = 0; i < length; ++i) {
            uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
            if (state.getCreditPosition(creditPositionId).debtPositionId == debtPositionId) {
                creditPositionIds[numberOfCreditPositions++] = creditPositionId;
            }
        }
        // downsize array length
        assembly {
            mstore(creditPositionIds, numberOfCreditPositions)
        }
    }

    function getCreditPositionsByDebtPositionId(uint256 debtPositionId)
        external
        view
        returns (CreditPosition[] memory creditPositions)
    {
        return getCreditPositions(getCreditPositionIdsByDebtPositionId(debtPositionId));
    }

    function getCryticVariables() external view returns (uint256 minimumCreditBorrowAToken, address feeRecipient) {
        return (state.riskConfig.minimumCreditBorrowAToken, state.feeConfig.feeRecipient);
    }
}
