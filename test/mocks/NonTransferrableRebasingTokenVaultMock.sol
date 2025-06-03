// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

contract NonTransferrableRebasingTokenVaultMock is NonTransferrableRebasingTokenVault {
    mapping(address user => uint256 shares) public sharesOfBefore;
    mapping(address user => uint256 shares) public sharesOfAfter;
    mapping(address user => address vault) public vaultOfBefore;
    mapping(address user => address vault) public vaultOfAfter;
    uint256 public _setVaultCount;
    uint256 public _setSharesOfCount;

    function setVault(address user, address vault) public override {
        sharesOfBefore[user] = sharesOf[user];
        vaultOfBefore[user] = vaultOf[user];
        super.setVault(user, vault);
        sharesOfAfter[user] = sharesOf[user];
        vaultOfAfter[user] = vaultOf[user];

        if (
            sharesOfBefore[user] > 0 && vaultOfBefore[user] != vaultOfAfter[user] && _setVaultCount != _setSharesOfCount
        ) {
            revert Errors.NOT_SUPPORTED();
        }
    }

    /// @dev Add before/after hooks to confirm that vaultOf and sharesOf are always in sync
    function _setVault(address user, address vault) internal virtual override {
        _setVaultCount++;
        super._setVault(user, vault);
    }

    function _setSharesOf(address user, uint256 shares) internal virtual override {
        _setSharesOfCount++;
        super._setSharesOf(user, shares);
    }
}
