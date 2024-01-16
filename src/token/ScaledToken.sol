// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {NonTransferrableToken} from "./NonTransferrableToken.sol";

import {IVariablePool} from "@src/interfaces/IVariablePool.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT, Rounding} from "@src/libraries/MathLibrary.sol";

/// @dev ScaledToken is a token that is scaled by a liquidity index
/// @notice A scaled amount is an unscaled amount divided by the liquidity index
contract ScaledToken is NonTransferrableToken {
    mapping(address => uint256) private previousIndex;

    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_)
        NonTransferrableToken(owner_, name_, symbol_)
    {}

    /// @dev Returns the UNSCALED balance of the user
    /// @param user The address of the user
    /// @param rounding rounding direction
    function _balanceOf(address user, Rounding rounding) internal view returns (uint256) {
        uint256 scaledBalance = super.balanceOf(user);
        uint256 index = IVariablePool(owner()).getReserveNormalizedIncome();
        return Math.mulDiv(scaledBalance, index, PERCENT, rounding);
    }

    /// @dev Returns the UNSCALED total supply of the token
    /// @param rounding rounding direction
    function _totalSupply(Rounding rounding) internal view returns (uint256) {
        uint256 scaledTotalSupply = super.totalSupply();
        uint256 index = IVariablePool(owner()).getReserveNormalizedIncome();
        return Math.mulDiv(scaledTotalSupply, index, PERCENT, rounding);
    }

    /// @dev Mints a scaled amount of tokens to the user
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to mint
    /// @param index the liquidity index
    /// @param rounding rounding direction
    function _mintScaled(address to, uint256 unscaledAmount, uint256 index, Rounding rounding) internal virtual {
        uint256 scaledAmount = Math.mulDiv(unscaledAmount, PERCENT, index, rounding);
        if (scaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        previousIndex[to] = index;
        _mint(to, scaledAmount);
    }

    /// @dev Burns a scaled amount of tokens from the user
    /// @param from user from which the scaled amount will be burnt
    /// @param unscaledAmount the unscaled amount of tokens to burn
    /// @param index the liquidity index
    /// @param rounding rounding direction
    function _burnScaled(address from, uint256 unscaledAmount, uint256 index, Rounding rounding) internal {
        uint256 scaledAmount = Math.mulDiv(unscaledAmount, PERCENT, index, rounding);
        if (scaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        previousIndex[from] = index;
        _burn(from, scaledAmount);
    }

    /// @dev Transfers a scaled amount of tokens from one user to another
    /// @param from user from which the scaled amount will be transferred
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to transfer
    /// @param index the liquidity index
    /// @param rounding rounding direction
    function _transferFromScaled(address from, address to, uint256 unscaledAmount, uint256 index, Rounding rounding)
        internal
        returns (bool)
    {
        previousIndex[from] = index;
        previousIndex[to] = index;

        uint256 scaledAmount = Math.mulDiv(unscaledAmount, PERCENT, index, rounding);
        if (scaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        _transfer(from, to, scaledAmount);
        return true;
    }

    /// @dev Transfers a scaled amount of tokens from the owner to another user
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to transfer
    /// @param index the liquidity index
    /// @param rounding rounding direction
    function _transferScaled(address to, uint256 unscaledAmount, uint256 index, Rounding rounding)
        internal
        returns (bool)
    {
        return _transferFromScaled(msg.sender, to, unscaledAmount, index, rounding);
    }

    /// @dev Function intentionally unsupported to prevent accidental minting of unscaled tokens
    function mint(address, uint256) external virtual override {
        revert Errors.NOT_SUPPORTED();
    }

    /// @dev Function intentionally unsupported to prevent accidental burning of unscaled tokens
    function burn(address, uint256) external virtual override {
        revert Errors.NOT_SUPPORTED();
    }

    /// @dev Function intentionally unsupported to prevent accidental transferring of unscaled tokens
    function transferFrom(address, address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @dev Function intentionally unsupported to prevent accidental transferring of unscaled tokens
    function transfer(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }
}
