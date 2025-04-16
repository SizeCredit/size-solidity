// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title Vault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
contract Vault is ERC4626 {
    constructor(IERC20Metadata _asset)
        ERC4626(_asset)
        ERC20(string.concat("Size ", _asset.name(), " Vault"), string.concat("sv", _asset.symbol()))
    {}
}
