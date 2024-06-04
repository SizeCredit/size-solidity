// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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

contract PoolMock is Ownable {
    using SafeERC20 for IERC20Metadata;

    struct Data {
        AToken aToken;
        VariableDebtToken debtToken;
        uint256 reserveIndex;
    }

    PoolAddressesProvider private immutable addressesProvider;
    mapping(address asset => Data data) private datas;

    constructor() Ownable(msg.sender) {
        addressesProvider = new PoolAddressesProvider("", address(this));
    }

    function setLiquidityIndex(address asset, uint256 index) public onlyOwner {
        Data storage data = datas[asset];
        if (data.reserveIndex == 0) {
            data.aToken = new AToken(IPool(address(this)));
            data.debtToken = new VariableDebtToken(IPool(address(this)));
            MockIncentivesController incentivesController = new MockIncentivesController();
            uint8 decimals = IERC20Metadata(asset).decimals();
            string memory name = IERC20Metadata(asset).name();
            string memory symbol = IERC20Metadata(asset).symbol();

            data.aToken.initialize(
                IPool(address(this)),
                owner(),
                asset,
                incentivesController,
                decimals,
                string.concat("aToken ", name),
                string.concat("a", IERC20Metadata(asset).symbol()),
                ""
            );
            data.debtToken.initialize(
                IPool(address(this)),
                asset,
                incentivesController,
                decimals,
                string.concat("VariableDebtToken ", name),
                string.concat("d", symbol),
                ""
            );
        }
        data.reserveIndex = index;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        Data memory data = datas[asset];
        IERC20Metadata(asset).transferFrom(msg.sender, address(this), amount);
        data.aToken.mint(address(this), onBehalfOf, amount, data.reserveIndex);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        Data memory data = datas[asset];
        data.aToken.burn(msg.sender, address(data.aToken), amount, data.reserveIndex);
        IERC20Metadata(asset).safeTransfer(to, amount);
        return amount;
    }

    function getReserveNormalizedIncome(address asset) external view returns (uint256) {
        return datas[asset].reserveIndex;
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory reserveData) {
        reserveData.aTokenAddress = address(datas[asset].aToken);
    }

    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(address(addressesProvider));
    }

    function finalizeTransfer(address, address, address, uint256, uint256, uint256) external pure {}
}
