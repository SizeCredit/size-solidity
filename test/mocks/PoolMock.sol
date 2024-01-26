// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IAaveIncentivesController} from "@aave/interfaces/IAaveIncentivesController.sol";
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

contract PoolMock is Ownable {
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
            aTokens[asset] = new AToken(IPool(address(this)));

            aTokens[asset].initialize(
                IPool(address(this)),
                owner(),
                asset,
                IAaveIncentivesController(address(0)),
                IERC20Metadata(asset).decimals(),
                string.concat("Size aToken ", IERC20Metadata(asset).name()),
                string.concat("asz", IERC20Metadata(asset).symbol()),
                ""
            );
            reserveIndexes.set(asset, WadRayMath.RAY);
        } else {
            // TODO: simulate interest
            // index = index * RATE / WadRayMath.RAY;
            reserveIndexes.set(asset, index);
        }
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        _updateLiquidityIndex(asset);
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        aTokens[asset].mint(address(this), onBehalfOf, amount, reserveIndexes.get(asset));
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        _updateLiquidityIndex(asset);
        aTokens[asset].burn(msg.sender, address(aTokens[asset]), amount, reserveIndexes.get(asset));
        IERC20Metadata(asset).safeTransfer(to, amount);
        return amount;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address) external {
        _updateLiquidityIndex(asset);
        debts[msg.sender][asset] += amount;
        IERC20Metadata(asset).safeTransfer(msg.sender, amount);
    }

    function repay(address asset, uint256 amount, uint256, address onBehalfOf) external returns (uint256) {
        _updateLiquidityIndex(asset);
        debts[onBehalfOf][asset] -= amount;
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        return amount;
    }

    function getUserAccountData(address)
        external
        pure
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

    function getReserveNormalizedIncome(address asset) external view returns (uint256) {
        return reserveIndexes.get(asset);
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) {
        DataTypes.ReserveData memory data;
        data.aTokenAddress = address(aTokens[asset]);
        return data;
    }

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
        return addressesProvider;
    }

    function finalizeTransfer(address, address, address, uint256, uint256, uint256) external pure {}
}
