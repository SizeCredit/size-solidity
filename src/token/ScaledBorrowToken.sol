// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ScaledToken} from "./ScaledToken.sol";
import {Rounding} from "@src/libraries/MathLibrary.sol";

contract ScaledBorrowToken is ScaledToken {
    // solhint-disable-next-line no-empty-blocks
    constructor(address owner_, string memory name_, string memory symbol_) ScaledToken(owner_, name_, symbol_) {}

    /// @dev Returns the UNSCALED balance of the user, rounding DOWN
    /// @param user The address of the user
    function balanceOf(address user) public view virtual override returns (uint256) {
        return _balanceOf(user, Rounding.DOWN);
    }

    /// @dev Returns the UNSCALED total supply of the token, rounding DOWN
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply(Rounding.DOWN);
    }

    /// @dev Mints a scaled amount of tokens to the user, rounding DOWN
    /// @param to user receiving the scaled amount
    /// @param unscaledAmount the unscaled amount of tokens to mint
    /// @param index the liquidity index
    function mintScaled(address to, uint256 unscaledAmount, uint256 index) public onlyOwner {
        _mintScaled(to, unscaledAmount, index, Rounding.DOWN);
    }

    /// @dev Burns a scaled amount of tokens from the user, rounding UP
    /// @param from user from which the scaled amount will be burnt
    /// @param unscaledAmount the unscaled amount of tokens to burn
    /// @param index the liquidity index
    function burnScaled(address from, uint256 unscaledAmount, uint256 index) public onlyOwner {
        _burnScaled(from, unscaledAmount, index, Rounding.UP);
    }
}