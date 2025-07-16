// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/market/Size.sol";
import {State} from "@src/market/SizeStorage.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Math, PERCENT, YEAR} from "@src/market/libraries/Math.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/market/libraries/LoanLibrary.sol";

contract SizeMock is Size {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    // https://github.com/foundry-rs/foundry/issues/4615
    bool public IS_TEST = true;

    function v() public pure returns (uint256) {
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

    function getAPR(uint256 cash, uint256 credit, uint256 tenor) external pure returns (uint256) {
        return Math.mulDivDown(credit - cash, YEAR * PERCENT, cash * tenor);
    }

    function getSwapFee(uint256 cash, uint256 tenor) public view returns (uint256) {
        if (tenor == 0) {
            revert Errors.NULL_TENOR();
        }
        return state.getSwapFee(cash, tenor);
    }

    function getDebtPositionAssignedCollateral(uint256 debtPositionId) external view returns (uint256) {
        DebtPosition memory debtPosition = state.getDebtPosition(debtPositionId);
        return state.getDebtPositionAssignedCollateral(debtPosition);
    }

    function isDebtPositionId(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionId(debtPositionId);
    }

    function isCreditPositionId(uint256 creditPositionId) external view returns (bool) {
        return state.isCreditPositionId(creditPositionId);
    }

    function getLoanStatus(uint256 positionId) external view returns (LoanStatus) {
        return state.getLoanStatus(positionId);
    }

    function isDebtPositionLiquidatable(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionLiquidatable(debtPositionId);
    }

    function getPositionsCount() external view returns (uint256, uint256) {
        return (
            state.data.nextDebtPositionId - DEBT_POSITION_ID_START,
            state.data.nextCreditPositionId - CREDIT_POSITION_ID_START
        );
    }
}
