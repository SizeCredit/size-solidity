// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {NonTransferrableToken} from "./NonTransferrableToken.sol";

import {IVariablePool} from "@src/interfaces/IVariablePool.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Rounding} from "@src/libraries/MathLibrary.sol";
import {WadRayMath} from "@src/libraries/variable/WadRayMathLibrary.sol";

// @audit Check maximum amount of minted tokens and analyse required TVL before it overflows
/// @dev ScaledToken is a token that is scaled by a liquidity index
/// @notice A scaled amount is an unscaled (underlying) amount divided by the liquidity index at the moment of the update
contract ScaledToken is NonTransferrableToken {
    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_)
        NonTransferrableToken(owner_, name_, symbol_)
    {}

    /// @dev The scaled balance is the sum of all the underlying asset of the user (amount deposited) divided by the reserve's liquidity index at the moment of the update
    /// @notice This essentially 'marks' when a user has deposited in the reserve pool, and can be used to calculate the users current compounded balance.
    /// @param user The address of the user
    /// @return The scaled balance of the user
    function scaledBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    /// @notice Returns the scaled total supply of the scaled balance token. Represents sum(debt/index)
    /// @return The scaled total supply
    function scaledTotalSupply() public view returns (uint256) {
        return super.totalSupply();
    }

    /// @dev Returns the UNSCALED balance of the user
    /// @param user The address of the user
    /// @param rounding rounding direction
    function _balanceOf(address user, Rounding rounding) internal view returns (uint256) {
        uint256 _scaledBalance = super.balanceOf(user);
        uint256 _indexRAY = IVariablePool(owner()).getReserveNormalizedIncomeRAY();
        return WadRayMath.rayMul(_scaledBalance, _indexRAY, rounding);
    }

    /// @dev Returns the UNSCALED total supply of the token
    /// @param rounding rounding direction
    function _totalSupply(Rounding rounding) internal view returns (uint256) {
        uint256 _scaledTotalSupply = super.totalSupply();
        uint256 _indexRAY = IVariablePool(owner()).getReserveNormalizedIncomeRAY();
        return WadRayMath.rayMul(_scaledTotalSupply, _indexRAY, rounding);
    }

    /// @dev Mints a scaled amount of tokens to the user
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to mint
    /// @param indexRAY the liquidity index
    /// @param rounding rounding direction
    function _mintScaled(address to, uint256 unscaledAmount, uint256 indexRAY, Rounding rounding) internal virtual {
        uint256 scaledAmount = WadRayMath.rayDiv(unscaledAmount, indexRAY, rounding);
        if (scaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        _mint(to, scaledAmount);
    }

    /// @dev Burns a scaled amount of tokens from the user
    /// @param from user from which the scaled amount will be burnt
    /// @param unscaledAmount the unscaled amount of tokens to burn
    /// @param indexRAY the liquidity index
    /// @param rounding rounding direction
    function _burnScaled(address from, uint256 unscaledAmount, uint256 indexRAY, Rounding rounding) internal {
        uint256 scaledAmount = WadRayMath.rayDiv(unscaledAmount, indexRAY, rounding);
        if (scaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        _burn(from, scaledAmount);
    }

    /// @dev Transfers a scaled amount of tokens from one user to another
    /// @param from user from which the scaled amount will be transferred
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to transfer
    /// @param indexRAY the liquidity index
    /// @param rounding rounding direction
    function _transferFromScaled(address from, address to, uint256 unscaledAmount, uint256 indexRAY, Rounding rounding)
        internal
        returns (bool)
    {
        uint256 scaledAmount = WadRayMath.rayDiv(unscaledAmount, indexRAY, rounding);
        if (scaledAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        _transfer(from, to, scaledAmount);
        return true;
    }

    /// @dev Transfers a scaled amount of tokens from the owner to another user
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to transfer
    /// @param indexRAY the liquidity index
    /// @param rounding rounding direction
    function _transferScaled(address to, uint256 unscaledAmount, uint256 indexRAY, Rounding rounding)
        internal
        returns (bool)
    {
        return _transferFromScaled(msg.sender, to, unscaledAmount, indexRAY, rounding);
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
