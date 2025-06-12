// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {SetVaultOnBehalfOfParams, SetVaultParams} from "@src/market/libraries/actions/SetVault.sol";

contract MaliciousERC4626Reentrancy is Ownable {
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
        size.setVaultOnBehalfOf(
            SetVaultOnBehalfOfParams({
                params: SetVaultParams({vault: address(0), forfeitOldShares: false}),
                onBehalfOf: owner()
            })
        );
        counter++;
        return amount;
    }

    function convertToAssets(uint256 shares) external pure returns (uint256 assets) {
        return shares;
    }
}
