// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";

contract NonTransferrableRebasingTokenVaultGhost is NonTransferrableRebasingTokenVault, PropertiesSpecifications {
    struct Vars {
        uint256 shareOf;
        address vaultOf;
    }

    mapping(address user => Vars vars) internal _before;
    mapping(address user => Vars vars) internal _after;
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

    modifier resetVars(address user) {
        _before[user].shareOf = 0;
        _before[user].vaultOf = INVALID_VAULT;
        _after[user].shareOf = 0;
        _after[user].vaultOf = INVALID_VAULT;
        countSetVaultOf = 0;
        countSetSharesOf = 0;
        _;
    }

    function __setVars(Vars storage vars, address user) internal {
        vars.shareOf = sharesOf[user];
        vars.vaultOf = vaultOf[user];
    }

    function __before(address user) internal {
        __setVars(_before[user], user);
    }

    function __after(address user) internal {
        __setVars(_after[user], user);
    }

    function setVault(address user, address vault, bool forfeitOldShares)
        public
        override
        resetVars(user)
        returns (address newVault)
    {
        __before(user);
        newVault = super.setVault(user, vault, forfeitOldShares);
        __after(user);

        if (
            _before[user].shareOf > 0 && _before[user].vaultOf != _after[user].vaultOf
                && (countSetVaultOf != 1 || countSetSharesOf == 0)
        ) {
            revert InvariantViolated(
                VAULTS_02,
                _before[user].shareOf,
                _after[user].shareOf,
                _before[user].vaultOf,
                _after[user].vaultOf,
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

    function deposit(address to, uint256 amount) public override resetVars(to) returns (uint256 assets) {
        __before(to);

        assets = super.deposit(to, amount);

        __after(to);

        if (_before[to].vaultOf != _after[to].vaultOf) {
            revert InvariantViolated(
                VAULTS_04,
                _before[to].shareOf,
                _after[to].shareOf,
                _before[to].vaultOf,
                _after[to].vaultOf,
                countSetVaultOf,
                countSetSharesOf
            );
        }

        return assets;
    }

    function withdraw(address from, address to, uint256 amount)
        public
        override
        resetVars(from)
        resetVars(to)
        returns (uint256 assets)
    {
        __before(from);
        __before(to);

        assets = super.withdraw(from, to, amount);

        __after(from);
        __after(to);

        if (_before[from].vaultOf != _after[from].vaultOf || _before[to].vaultOf != _after[to].vaultOf) {
            revert InvariantViolated(
                VAULTS_04,
                _before[from].shareOf,
                _after[from].shareOf,
                _before[from].vaultOf,
                _after[from].vaultOf,
                countSetVaultOf,
                countSetSharesOf
            );
        }

        return assets;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        resetVars(from)
        resetVars(to)
        returns (bool)
    {
        __before(from);
        __before(to);

        bool success = super.transferFrom(from, to, amount);

        __after(from);
        __after(to);

        if (_before[from].vaultOf != _after[from].vaultOf || _before[to].vaultOf != _after[to].vaultOf) {
            revert InvariantViolated(
                VAULTS_04,
                _before[from].shareOf,
                _after[from].shareOf,
                _before[from].vaultOf,
                _after[from].vaultOf,
                countSetVaultOf,
                countSetSharesOf
            );
        }

        return success;
    }
}
