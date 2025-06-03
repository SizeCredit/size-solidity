// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";

contract NonTransferrableRebasingTokenVaultMock is NonTransferrableRebasingTokenVault, PropertiesSpecifications {
    mapping(address user => uint256 shares) public sharesOfBefore;
    mapping(address user => uint256 shares) public sharesOfAfter;
    mapping(address user => address vault) public vaultOfBefore;
    mapping(address user => address vault) public vaultOfAfter;
    uint256 public countSetVaultOf;
    uint256 public countSetSharesOf;

    address public constant INVALID_VAULT = address(type(uint160).max);

    error InvariantViolated(
        string property,
        uint256 sharesOfBefore,
        uint256 sharesOfAfter,
        address vaultOfBefore,
        address vaultOfAfter,
        uint256 countSetVaultOf,
        uint256 countSetSharesOf
    );

    modifier resetState(address user) {
        sharesOfBefore[user] = 0;
        vaultOfBefore[user] = INVALID_VAULT;
        sharesOfAfter[user] = 0;
        vaultOfAfter[user] = INVALID_VAULT;
        countSetVaultOf = 0;
        countSetSharesOf = 0;
        _;
    }

    function setVault(address user, address vault) public override resetState(user) {
        sharesOfBefore[user] = sharesOf[user];
        vaultOfBefore[user] = vaultOf[user];

        super.setVault(user, vault);

        sharesOfAfter[user] = sharesOf[user];
        vaultOfAfter[user] = vaultOf[user];

        if (
            sharesOfBefore[user] > 0 && vaultOfBefore[user] != vaultOfAfter[user]
                && (countSetVaultOf != 1 || countSetSharesOf == 0)
        ) {
            // TODO this can also be violated in `deposit` and `withdraw`
            revert InvariantViolated(
                VAULTS_02,
                sharesOfBefore[user],
                sharesOfAfter[user],
                vaultOfBefore[user],
                vaultOfAfter[user],
                countSetVaultOf,
                countSetSharesOf
            );
        }
    }

    function _setVaultOf(address user, address vault) internal virtual override {
        countSetVaultOf++;
        super._setVaultOf(user, vault);
    }

    function _setSharesOf(address user, uint256 shares) internal virtual override {
        countSetSharesOf++;
        super._setSharesOf(user, shares);
    }
}
