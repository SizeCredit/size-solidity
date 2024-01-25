// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/interfaces/IPoolAddressesProvider.sol";

import {PoolAddressesProvider} from "@aave/protocol/configuration/PoolAddressesProvider.sol";
import {AToken} from "@aave/protocol/tokenization/AToken.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {DataTypes} from "@aave/protocol/libraries/types/DataTypes.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract PoolMock is Ownable, IPool {
    using SafeERC20 for IERC20Metadata;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 public constant RATE = 1.01e27;
    EnumerableMap.AddressToUintMap internal reserveIndexes;
    PoolAddressesProvider internal addressesProvider;
    mapping(address user => mapping(address asset => uint256 amount)) internal debts;
    mapping(address asset => AToken aToken) internal aTokens;

    constructor() Ownable(msg.sender) {}

    function setLiquidityIndex(address asset, uint256 index) external onlyOwner {
        _updateLiquidityIndex(asset);
        reserveIndexes.set(asset, index);
    }

    function _updateLiquidityIndex(address asset) private {
        (bool exists, uint256 index) = reserveIndexes.tryGet(asset);
        if (!exists) {
            addressesProvider = new PoolAddressesProvider(IERC20Metadata(asset).name(), address(this));
            aTokens[asset] = new AToken(this);
            reserveIndexes.set(asset, WadRayMath.RAY);
        } else {
            // TODO: simulate interest
            // index = index * RATE / WadRayMath.RAY;
            reserveIndexes.set(asset, index);
        }
    }

    function mintUnbacked(address, uint256, address, uint16) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function backUnbacked(address, uint256, uint256) external pure override returns (uint256) {
        revert Errors.NOT_SUPPORTED();
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external override {
        _updateLiquidityIndex(asset);
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        aTokens[asset].mint(address(this), onBehalfOf, amount, reserveIndexes.get(asset));
    }

    function supplyWithPermit(address, uint256, address, uint16, uint256, uint8, bytes32, bytes32)
        external
        pure
        override
    {
        revert Errors.NOT_SUPPORTED();
    }

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        _updateLiquidityIndex(asset);
        aTokens[asset].burn(msg.sender, address(aTokens[asset]), amount, reserveIndexes.get(asset));
        IERC20Metadata(asset).safeTransfer(to, amount);
        return amount;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address) external override {
        _updateLiquidityIndex(asset);
        debts[msg.sender][asset] += amount;
        IERC20Metadata(asset).safeTransfer(msg.sender, amount);
    }

    function repay(address asset, uint256 amount, uint256, address onBehalfOf) external override returns (uint256) {
        _updateLiquidityIndex(asset);
        debts[onBehalfOf][asset] -= amount;
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        return amount;
    }

    function repayWithPermit(address, uint256, uint256, address, uint256, uint8, bytes32, bytes32)
        external
        pure
        override
        returns (uint256)
    {
        revert Errors.NOT_SUPPORTED();
    }

    function repayWithATokens(address, uint256, uint256) external pure override returns (uint256) {
        revert Errors.NOT_SUPPORTED();
    }

    function swapBorrowRateMode(address, uint256) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function rebalanceStableBorrowRate(address, address) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function setUserUseReserveAsCollateral(address, bool) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function liquidationCall(address, address, address, uint256, bool) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function flashLoan(
        address,
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        address,
        bytes calldata,
        uint16
    ) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function flashLoanSimple(address, address, uint256, bytes calldata, uint16) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function getUserAccountData(address)
        external
        pure
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return (0, 0, 0, 0, 0, 0);
    }

    function initReserve(address, address, address, address, address) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function dropReserve(address) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function setReserveInterestRateStrategyAddress(address, address) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function setConfiguration(address, DataTypes.ReserveConfigurationMap calldata) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function getConfiguration(address) external pure override returns (DataTypes.ReserveConfigurationMap memory) {
        revert Errors.NOT_SUPPORTED();
    }

    function getUserConfiguration(address) external pure override returns (DataTypes.UserConfigurationMap memory) {
        revert Errors.NOT_SUPPORTED();
    }

    function getReserveNormalizedIncome(address asset) external view override returns (uint256) {
        return reserveIndexes.get(asset);
    }

    function getReserveNormalizedVariableDebt(address) external pure override returns (uint256) {
        revert Errors.NOT_SUPPORTED();
    }

    function getReserveData(address asset) external view override returns (DataTypes.ReserveData memory) {
        DataTypes.ReserveData memory data;
        data.aTokenAddress = address(aTokens[asset]);
        return data;
    }

    function finalizeTransfer(address, address, address, uint256, uint256, uint256) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function getReservesList() external view override returns (address[] memory) {}

    function getReserveAddressById(uint16) external pure override returns (address) {
        revert Errors.NOT_SUPPORTED();
    }

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return addressesProvider;
    }

    function updateBridgeProtocolFee(uint256) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function updateFlashloanPremiums(uint128, uint128) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function configureEModeCategory(uint8, DataTypes.EModeCategory memory) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function getEModeCategoryData(uint8) external pure override returns (DataTypes.EModeCategory memory) {
        revert Errors.NOT_SUPPORTED();
    }

    function setUserEMode(uint8) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function getUserEMode(address) external pure override returns (uint256) {
        revert Errors.NOT_SUPPORTED();
    }

    function resetIsolationModeTotalDebt(address) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external pure override returns (uint256) {
        revert Errors.NOT_SUPPORTED();
    }

    function FLASHLOAN_PREMIUM_TOTAL() external pure override returns (uint128) {
        revert Errors.NOT_SUPPORTED();
    }

    function BRIDGE_PROTOCOL_FEE() external pure override returns (uint256) {
        revert Errors.NOT_SUPPORTED();
    }

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external pure override returns (uint128) {
        revert Errors.NOT_SUPPORTED();
    }

    function MAX_NUMBER_RESERVES() external pure override returns (uint16) {
        revert Errors.NOT_SUPPORTED();
    }

    function mintToTreasury(address[] calldata) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function rescueTokens(address, address, uint256) external pure override {
        revert Errors.NOT_SUPPORTED();
    }

    function deposit(address, uint256, address, uint16) external pure override {
        revert Errors.NOT_SUPPORTED();
    }
}
