// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {
    SetUserConfigurationOnBehalfOfParams,
    SetUserConfigurationParams
} from "@src/market/libraries/actions/SetUserConfiguration.sol";

contract ReentrancyMaliciousERC4626 is Ownable {
    address public immutable asset;
    ISize public immutable size;
    uint256 public counter;

    constructor(address _asset, ISize _size, address _owner) Ownable(_owner) {
        asset = _asset;
        size = _size;
    }

    function balanceOf(address) public view returns (uint256) {
        if (counter == 0) {
            return 0;
        }
        return type(uint128).max;
    }

    function deposit(uint256 amount, address) public returns (uint256) {
        SetUserConfigurationParams memory params = SetUserConfigurationParams({
            vault: address(0),
            openingLimitBorrowCR: 1.5e18,
            allCreditPositionsForSaleDisabled: false,
            creditPositionIdsForSale: false,
            creditPositionIds: new uint256[](0)
        });
        SetUserConfigurationOnBehalfOfParams memory config = SetUserConfigurationOnBehalfOfParams(params, owner());
        size.setUserConfigurationOnBehalfOf(config);
        counter++;
        return amount;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256 assets) {
        return shares;
    }
}
