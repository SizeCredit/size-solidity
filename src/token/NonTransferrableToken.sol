// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract NonTransferrableToken is Ownable2Step, ERC20 {
    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_) Ownable(owner_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
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
}
