// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {Math as MathOZ} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";

contract FeeOnTransferERC4626 is ERC4626, Ownable {
    uint256 public feePercent;
    uint256 private __UPDATE_COUNTER;

    constructor(IERC20 underlying_, string memory name_, string memory symbol_, uint256 feePercent_)
        ERC4626(underlying_)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        feePercent = feePercent_;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        uint256 numberOfUpdates = 2 + (from != address(0) ? 1 : 0) + (to != address(0) ? 1 : 0);
        super._update(from, to, value);
        __UPDATE_COUNTER++;

        uint256 fee = Math.mulDivDown(value, feePercent, PERCENT);
        if (__UPDATE_COUNTER % numberOfUpdates == 1) {
            if (from != address(0)) {
                _burn(from, fee);
            }
            if (to != address(0)) {
                _burn(to, fee);
            }

            _mint(owner(), fee);
        }
    }
}
