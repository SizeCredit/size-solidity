// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";

contract FeeOnTransferERC4626 is ERC4626 {
    uint256 public feePercent;
    bool private lock;

    constructor(IERC20 underlying_, string memory name_, string memory symbol_, uint256 feePercent_)
        ERC4626(underlying_)
        ERC20(name_, symbol_)
    {
        feePercent = feePercent_;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (lock) {
            lock = false;
            return;
        }
        lock = true;

        super._update(from, to, value);
        uint256 fee = Math.mulDivDown(value, feePercent, PERCENT);
        _mint(address(this), fee);
    }
}
