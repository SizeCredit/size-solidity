// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SizeStorage, State, User} from "@src/market/SizeStorage.sol";

import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/market/libraries/YieldCurveLibrary.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus,
    RESERVED_ID
} from "@src/market/libraries/LoanLibrary.sol";
import {UpdateConfig} from "@src/market/libraries/actions/UpdateConfig.sol";

import {DataView, UserView} from "@src/market/SizeViewData.sol";
import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

import {ISizeView} from "@src/market/interfaces/ISizeView.sol";
import {ISizeViewV1_8} from "@src/market/interfaces/v1.8/ISizeViewV1_8.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

import {BuyCreditMarket, BuyCreditMarketWithCollectionParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";
import {
    SellCreditMarket, SellCreditMarketWithCollectionParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISizeViewV1_7} from "@src/market/interfaces/v1.7/ISizeViewV1_7.sol";

import {VERSION} from "@src/market/interfaces/ISize.sol";

/// @title SizeView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice View methods for the Size protocol
abstract contract SizeView is SizeStorage, ISizeView {
    using OfferLibrary for LimitOrder;
    using OfferLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using AccountingLibrary for State;
    using UpdateConfig for State;

    /// @inheritdoc ISizeView
    function collateralRatio(address user) external view returns (uint256) {
        return state.collateralRatio(user);
    }

    /// @inheritdoc ISizeView
    function isDebtPositionLiquidatable(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionLiquidatable(debtPositionId);
    }

    /// @inheritdoc ISizeView
    function debtTokenAmountToCollateralTokenAmount(uint256 amount) external view returns (uint256) {
        return state.debtTokenAmountToCollateralTokenAmount(amount);
    }

    /// @inheritdoc ISizeView
    function feeConfig() external view returns (InitializeFeeConfigParams memory) {
        return state.feeConfigParams();
    }

    /// @inheritdoc ISizeView
    function riskConfig() external view returns (InitializeRiskConfigParams memory) {
        return state.riskConfigParams();
    }

    /// @inheritdoc ISizeView
    function oracle() external view returns (InitializeOracleParams memory) {
        return state.oracleParams();
    }

    /// @inheritdoc ISizeView
    function data() external view returns (DataView memory) {
        return DataView({
            nextDebtPositionId: state.data.nextDebtPositionId,
            nextCreditPositionId: state.data.nextCreditPositionId,
            underlyingCollateralToken: state.data.underlyingCollateralToken,
            underlyingBorrowToken: state.data.underlyingBorrowToken,
            variablePool: state.data.variablePool,
            collateralToken: state.data.collateralToken,
            borrowTokenVault: state.data.borrowTokenVault,
            debtToken: state.data.debtToken
        });
    }

    /// @inheritdoc ISizeViewV1_7
    function sizeFactory() external view returns (ISizeFactory) {
        return state.data.sizeFactory;
    }

    /// @inheritdoc ISizeView
    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state.data.users[user],
            account: user,
            collateralTokenBalance: state.data.collateralToken.balanceOf(user),
            borrowTokenBalance: state.data.borrowTokenVault.balanceOf(user),
            debtBalance: state.data.debtToken.balanceOf(user)
        });
    }

    /// @inheritdoc ISizeViewV1_8
    function getUserDefinedCopyLoanOfferConfig(address user) external view returns (CopyLimitOrderConfig memory) {
        return state.data.usersCopyLimitOrders[user].copyLoanOfferConfig;
    }

    /// @inheritdoc ISizeViewV1_8
    function getUserDefinedCopyBorrowOfferConfig(address user) external view returns (CopyLimitOrderConfig memory) {
        return state.data.usersCopyLimitOrders[user].copyBorrowOfferConfig;
    }

    /// @inheritdoc ISizeView
    function vaultOf(address user) external view returns (address) {
        return state.data.borrowTokenVault.vaultOf(user);
    }

    /// @inheritdoc ISizeView
    function isDebtPositionId(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionId(debtPositionId);
    }

    /// @inheritdoc ISizeView
    function isCreditPositionId(uint256 creditPositionId) external view returns (bool) {
        return state.isCreditPositionId(creditPositionId);
    }

    /// @inheritdoc ISizeView
    function getDebtPosition(uint256 debtPositionId) external view returns (DebtPosition memory) {
        return state.getDebtPosition(debtPositionId);
    }

    /// @inheritdoc ISizeView
    function getCreditPosition(uint256 creditPositionId) external view returns (CreditPosition memory) {
        return state.getCreditPosition(creditPositionId);
    }

    /// @inheritdoc ISizeView
    function getLoanStatus(uint256 positionId) external view returns (LoanStatus) {
        return state.getLoanStatus(positionId);
    }

    /// @inheritdoc ISizeView
    function getPositionsCount() external view returns (uint256, uint256) {
        return (
            state.data.nextDebtPositionId - DEBT_POSITION_ID_START,
            state.data.nextCreditPositionId - CREDIT_POSITION_ID_START
        );
    }

    /// @inheritdoc ISizeViewV1_8
    function getUserDefinedLoanOfferAPR(address lender, uint256 tenor) external view returns (uint256) {
        return state.getUserDefinedLoanOfferAPR(lender, tenor);
    }

    /// @inheritdoc ISizeViewV1_8
    function getUserDefinedBorrowOfferAPR(address borrower, uint256 tenor) external view returns (uint256) {
        return state.getUserDefinedBorrowOfferAPR(borrower, tenor);
    }

    /// @inheritdoc ISizeViewV1_8
    function getLoanOfferAPR(address user, uint256 collectionId, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256)
    {
        return state.getLoanOfferAPR(user, collectionId, rateProvider, tenor);
    }

    /// @inheritdoc ISizeViewV1_8
    function getBorrowOfferAPR(address user, uint256 collectionId, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256)
    {
        return state.getBorrowOfferAPR(user, collectionId, rateProvider, tenor);
    }

    /// @inheritdoc ISizeView
    function getBuyCreditMarketSwapData(BuyCreditMarketWithCollectionParams memory withCollectionParams)
        external
        view
        returns (BuyCreditMarket.SwapDataBuyCreditMarket memory)
    {
        return BuyCreditMarket.getSwapData(state, withCollectionParams);
    }

    /// @inheritdoc ISizeView
    function getSellCreditMarketSwapData(SellCreditMarketWithCollectionParams memory withCollectionParams)
        external
        view
        returns (SellCreditMarket.SwapDataSellCreditMarket memory)
    {
        return SellCreditMarket.getSwapData(state, withCollectionParams);
    }

    /// @inheritdoc ISizeView
    function version() public pure returns (string memory) {
        return VERSION;
    }
}
