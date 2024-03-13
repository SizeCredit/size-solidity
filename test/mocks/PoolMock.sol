// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/interfaces/IPoolAddressesProvider.sol";

import {PoolAddressesProvider} from "@aave/protocol/configuration/PoolAddressesProvider.sol";
import {AToken} from "@aave/protocol/tokenization/AToken.sol";

import {DataTypes} from "@aave/protocol/libraries/types/DataTypes.sol";

import {MockIncentivesController} from "@aave/mocks/helpers/MockIncentivesController.sol";
import {VariableDebtToken} from "@aave/protocol/tokenization/VariableDebtToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Math} from "@src/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

contract PoolMock is Ownable {
    using SafeERC20 for IERC20Metadata;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap internal reserveIndexes;
    PoolAddressesProvider internal immutable addressesProvider;
    IPriceFeed internal immutable priceFeed;

    mapping(address asset => AToken aToken) internal aTokens;
    mapping(address asset => VariableDebtToken) internal debtTokens;
    mapping(address asset => bool) internal isCollateralToken;
    MockIncentivesController internal incentivesController;

    constructor(IPriceFeed _priceFeed) Ownable(msg.sender) {
        addressesProvider = new PoolAddressesProvider("", address(this));
        priceFeed = _priceFeed;
    }

    function setLiquidityIndex(address asset, uint256 index, bool isCollateral) external onlyOwner {
        setLiquidityIndex(asset, index);
        isCollateralToken[asset] = isCollateral;
    }

    function setLiquidityIndex(address asset, uint256 index) public onlyOwner {
        (bool exists,) = reserveIndexes.tryGet(asset);
        if (!exists) {
            aTokens[asset] = new AToken(IPool(address(this)));
            debtTokens[asset] = new VariableDebtToken(IPool(address(this)));

            aTokens[asset].initialize(
                IPool(address(this)),
                owner(),
                asset,
                incentivesController,
                IERC20Metadata(asset).decimals(),
                string.concat("Size aToken ", IERC20Metadata(asset).name()),
                string.concat("asz", IERC20Metadata(asset).symbol()),
                ""
            );
            debtTokens[asset].initialize(
                IPool(address(this)),
                asset,
                incentivesController,
                IERC20Metadata(asset).decimals(),
                string.concat("Size variableDebtToken ", IERC20Metadata(asset).name()),
                string.concat("dsz", IERC20Metadata(asset).symbol()),
                ""
            );
        }
        reserveIndexes.set(asset, index);
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        aTokens[asset].mint(address(this), onBehalfOf, amount, reserveIndexes.get(asset));
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        aTokens[asset].burn(msg.sender, address(aTokens[asset]), amount, reserveIndexes.get(asset));
        IERC20Metadata(asset).safeTransfer(to, amount);
        return amount;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address) external {
        debtTokens[asset].mint(msg.sender, msg.sender, amount, reserveIndexes.get(asset));
        IERC20Metadata(asset).safeTransfer(msg.sender, amount);
    }

    function repay(address asset, uint256 amount, uint256, address onBehalfOf) external returns (uint256) {
        debtTokens[asset].burn(onBehalfOf, amount, reserveIndexes.get(asset));
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        return amount;
    }

    function repayWithATokens(address asset, uint256 amount, uint256) external returns (uint256) {
        amount = Math.min(amount, debtTokens[asset].balanceOf(msg.sender));
        debtTokens[asset].burn(msg.sender, amount, reserveIndexes.get(asset));
        aTokens[asset].burn(msg.sender, address(aTokens[asset]), amount, reserveIndexes.get(asset));
        return amount;
    }

    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool)
        public
    {
        uint8 decimals = IERC20Metadata(collateralAsset).decimals() - IERC20Metadata(debtAsset).decimals();
        uint256 collateralAmount = debtToCover * 10 ** decimals * (10 ** priceFeed.decimals()) / priceFeed.getPrice();
        IERC20Metadata(debtAsset).transferFrom(msg.sender, address(this), debtToCover);
        aTokens[collateralAsset].transferOnLiquidation(user, msg.sender, collateralAmount);
        debtTokens[debtAsset].burn(user, debtToCover, reserveIndexes.get(debtAsset));
    }

    function getUserAccountData(address user)
        external
        view
        returns (uint256 totalCollateralBase, uint256 totalDebtBase, uint256, uint256, uint256, uint256 healthFactor)
    {
        uint256 length = reserveIndexes.length();
        address collateralAsset;
        address debtAsset;
        for (uint256 i = 0; i < length; i++) {
            (address asset,) = reserveIndexes.at(i);
            if (isCollateralToken[asset]) {
                collateralAsset = asset;
            } else {
                debtAsset = asset;
            }
        }

        uint8 decimals = IERC20Metadata(collateralAsset).decimals() - IERC20Metadata(debtAsset).decimals();
        totalCollateralBase = aTokens[collateralAsset].balanceOf(user);
        totalDebtBase = debtTokens[debtAsset].balanceOf(user);
        healthFactor = totalCollateralBase * priceFeed.getPrice() / (totalDebtBase * 10 ** decimals);
    }

    function getReserveNormalizedIncome(address asset) external view returns (uint256) {
        return reserveIndexes.get(asset);
    }

    function getReserveNormalizedVariableDebt(address asset) external view returns (uint256) {
        return reserveIndexes.get(asset);
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) {
        DataTypes.ReserveData memory data;
        data.aTokenAddress = address(aTokens[asset]);
        data.variableDebtTokenAddress = address(debtTokens[asset]);
        return data;
    }

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
        return addressesProvider;
    }

    function finalizeTransfer(address, address, address, uint256, uint256, uint256) external pure {}

    function setUserUseReserveAsCollateral(address, bool) external pure {}
}
