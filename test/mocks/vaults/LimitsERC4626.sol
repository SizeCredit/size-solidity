// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract LimitsERC4626 is ERC4626 {
    uint256 internal _maxDeposit;
    uint256 internal _maxMint;
    uint256 internal _maxWithdraw;
    uint256 internal _maxRedeem;

    constructor(
        IERC20 underlying_,
        string memory name_,
        string memory symbol_,
        uint256 maxDeposit_,
        uint256 maxMint_,
        uint256 maxWithdraw_,
        uint256 maxRedeem_
    ) ERC4626(underlying_) ERC20(name_, symbol_) {
        _maxDeposit = maxDeposit_;
        _maxMint = maxMint_;
        _maxWithdraw = maxWithdraw_;
        _maxRedeem = maxRedeem_;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return _maxDeposit;
    }

    function maxMint(address) public view override returns (uint256) {
        return _maxMint;
    }

    function maxWithdraw(address) public view override returns (uint256) {
        return _maxWithdraw;
    }

    function maxRedeem(address) public view override returns (uint256) {
        return _maxRedeem;
    }
}
