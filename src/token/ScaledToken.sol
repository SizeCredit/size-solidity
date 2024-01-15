// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {NonTransferrableToken} from "./NonTransferrableToken.sol";

import {IVariablePool} from "@src/interfaces/IVariablePool.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT, Rounding} from "@src/libraries/MathLibrary.sol";

// scaled = unscaled / index
contract ScaledToken is NonTransferrableToken {
    mapping(address => uint256) private previousIndex;
    IVariablePool private variablePool;

    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_, address variablePool_)
        NonTransferrableToken(owner_, name_, symbol_)
    {
        if (variablePool_ == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        variablePool = IVariablePool(variablePool_);
    }

    function balanceOf(address user) public view override returns (uint256) {
        uint256 scaledBalance = super.balanceOf(user);
        uint256 index = variablePool.getReserveNormalizedIncome();
        return Math.mulDivDown(scaledBalance, index, PERCENT);
    }

    function totalSupply() public view override returns (uint256) {
        uint256 scaledTotalSupply = super.totalSupply();

        if (scaledTotalSupply > 0) {
            uint256 index = variablePool.getReserveNormalizedIncome();
            return Math.mulDivDown(scaledTotalSupply, index, PERCENT);
        } else {
            return 0;
        }
    }

    function mintScaled(address to, uint256 amount, uint256 index, Rounding rounding) public onlyOwner {
        uint256 amountScaled =
            rounding == Rounding.DOWN ? Math.mulDivDown(amount, PERCENT, index) : Math.mulDivUp(amount, PERCENT, index);
        if (amountScaled == 0) {
            revert Errors.NULL_AMOUNT();
        }
        previousIndex[to] = index;
        _mint(to, amountScaled);
    }

    function burnScaled(address from, uint256 amount, uint256 index, Rounding rounding) public onlyOwner {
        uint256 amountScaled =
            rounding == Rounding.UP ? Math.mulDivUp(amount, PERCENT, index) : Math.mulDivDown(amount, PERCENT, index);
        if (amountScaled == 0) {
            revert Errors.NULL_AMOUNT();
        }
        previousIndex[from] = index;
        _burn(from, amountScaled);
    }

    function transferFromScaled(address from, address to, uint256 amount, uint256 index, Rounding rounding)
        public
        onlyOwner
        returns (bool)
    {
        previousIndex[from] = index;
        previousIndex[to] = index;

        uint256 unscaledAmount =
            rounding == Rounding.UP ? Math.mulDivUp(amount, PERCENT, index) : Math.mulDivDown(amount, PERCENT, index);
        if (unscaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        _transfer(from, to, unscaledAmount);
        return true;
    }

    function transferScaled(address to, uint256 amount, uint256 index, Rounding rounding)
        public
        onlyOwner
        returns (bool)
    {
        return transferFromScaled(msg.sender, to, amount, index, rounding);
    }
}
