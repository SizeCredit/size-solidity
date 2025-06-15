// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MaliciousERC4626 is ERC4626 {
    error WithdrawNotAllowed();

    constructor(IERC20 underlying_, string memory name_, string memory symbol_)
        ERC4626(underlying_)
        ERC20(name_, symbol_)
    {}

    function _withdraw(address, address, address, uint256, uint256) internal virtual override {
        revert WithdrawNotAllowed();
    }
}
