// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SizeStorage, State} from "@src/SizeStorage.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/libraries/fixed/LoanLibrary.sol";
import {UpdateConfig} from "@src/libraries/general/actions/UpdateConfig.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {
    InitializeConfigParams,
    InitializeDataParams,
    InitializeOracleParams
} from "@src/libraries/general/actions/Initialize.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

struct UserView {
    User user;
    address account;
    uint256 collateralAmount;
    uint256 borrowAmount;
    uint256 debtAmount;
}

struct DataView {
    uint256 nextDebtPositionId;
    uint256 nextCreditPositionId;
    IERC20Metadata underlyingCollateralToken;
    IERC20Metadata underlyingBorrowToken;
    IPool variablePool;
    NonTransferrableToken collateralToken;
    IAToken borrowAToken;
    NonTransferrableToken debtToken;
}

/// @title SizeView
/// @notice View methods for the Size protocol
abstract contract SizeView is SizeStorage {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;
    using UpdateConfig for State;

    function collateralRatio(address user) external view returns (uint256) {
        return state.collateralRatio(user);
    }

    function isUserLiquidatable(address user) external view returns (bool) {
        return state.isUserLiquidatable(user);
    }

    function isDebtPositionLiquidatable(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionLiquidatable(debtPositionId);
    }

    function getDebtPositionAssignedCollateral(uint256 debtPositionId) external view returns (uint256) {
        DebtPosition memory debtPosition = state.getDebtPosition(debtPositionId);
        return state.getDebtPositionAssignedCollateral(debtPosition);
    }

    function getDebt(uint256 debtPositionId) external view returns (uint256) {
        return state.getDebtPosition(debtPositionId).getDebt();
    }

    function faceValue(uint256 debtPositionId) external view returns (uint256) {
        return state.getDebtPosition(debtPositionId).faceValue();
    }

    function faceValueInCollateralToken(uint256 debtPositionId) external view returns (uint256) {
        return state.faceValueInCollateralToken(state.getDebtPosition(debtPositionId));
    }

    function getDueDate(uint256 debtPositionId) external view returns (uint256) {
        return state.getDebtPosition(debtPositionId).dueDate;
    }

    function getCredit(uint256 creditPositionId) external view returns (uint256) {
        return state.getCreditPosition(creditPositionId).credit;
    }

    function config() external view returns (InitializeConfigParams memory) {
        return state.configParams();
    }

    function oracle() external view returns (InitializeOracleParams memory) {
        return state.oracleParams();
    }

    function data() external view returns (DataView memory) {
        return DataView({
            nextDebtPositionId: state.data.nextDebtPositionId,
            nextCreditPositionId: state.data.nextCreditPositionId,
            underlyingCollateralToken: state.data.underlyingCollateralToken,
            underlyingBorrowToken: state.data.underlyingBorrowToken,
            variablePool: state.data.variablePool,
            collateralToken: state.data.collateralToken,
            borrowAToken: state.data.borrowAToken,
            debtToken: state.data.debtToken
        });
    }

    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state.data.users[user],
            account: user,
            collateralAmount: state.data.collateralToken.balanceOf(user),
            borrowAmount: state.borrowATokenBalanceOf(user),
            debtAmount: state.data.debtToken.balanceOf(user)
        });
    }

    function getVaultAddress(address user) external view returns (address) {
        return address(state.data.users[user].vault);
    }

    function isDebtPositionId(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionId(debtPositionId);
    }

    function isCreditPositionId(uint256 creditPositionId) external view returns (bool) {
        return state.isCreditPositionId(creditPositionId);
    }

    function getDebtPosition(uint256 debtPositionId) external view returns (DebtPosition memory) {
        return state.getDebtPosition(debtPositionId);
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

    function getCreditPosition(uint256 creditPositionId) external view returns (CreditPosition memory) {
        return state.getCreditPosition(creditPositionId);
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

    function getLoanStatus(uint256 positionId) external view returns (LoanStatus) {
        return state.getLoanStatus(positionId);
    }

    function partialRepayFee(uint256 debtPositionId, uint256 repayAmount) public view returns (uint256) {
        return state.getDebtPosition(debtPositionId).partialRepayFee(repayAmount);
    }

    function repayFee(uint256 debtPositionId) external view returns (uint256) {
        return state.getDebtPosition(debtPositionId).repayFee();
    }

    function repayFee(uint256 issuanceValue, uint256 startDate, uint256 dueDate, uint256 repayFeeAPR)
        external
        pure
        returns (uint256)
    {
        return LoanLibrary.repayFee(issuanceValue, startDate, dueDate, repayFeeAPR);
    }

    function getPositionsCount() external view returns (uint256, uint256) {
        return (
            state.data.nextDebtPositionId - DEBT_POSITION_ID_START,
            state.data.nextCreditPositionId - CREDIT_POSITION_ID_START
        );
    }
}
