// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract NonTransferrableToken is Ownable, ERC20 {
    uint8 internal immutable _decimals;

    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        Ownable(owner_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external virtual onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external virtual onlyOwner {
        _burn(from, amount);
    }

    function transferFrom(address from, address to, uint256 value) public virtual override onlyOwner returns (bool) {
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint256 value) public virtual override onlyOwner returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address, address spender) public view virtual override returns (uint256) {
        return spender == owner() ? type(uint256).max : 0;
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
