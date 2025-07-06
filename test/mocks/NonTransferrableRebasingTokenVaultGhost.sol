// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";

contract NonTransferrableRebasingTokenVaultGhost is NonTransferrableRebasingTokenVault, PropertiesSpecifications {
    using EnumerableMap for EnumerableMap.AddressToBytes32Map;

    struct Vars {
        uint256 shareOf;
        address vaultOf;
    }

    constructor() {
        bytes32 slot = _initializableStorageSlot();
        // re-enables initialize()
        assembly {
            sstore(slot, 0)
        }
    }

    mapping(address user => Vars vars) internal _before;
    mapping(address user => Vars vars) internal _after;
    uint256 public countSetVaultOf;
    uint256 public countSetSharesOf;

    address public constant INVALID_VAULT = address(type(uint160).max);

    event InvariantViolatedEvent(
        string property,
        uint256 sharesOfBefore,
        uint256 sharesOfAfter,
        address vaultOfBefore,
        address vaultOfAfter,
        uint256 countSetVaultOf,
        uint256 countSetSharesOf
    );

    error InvariantViolatedError(
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

    function setVault(address user, address vault, bool forfeitOldShares) public virtual override resetVars(user) {
        __before(user);
        super.setVault(user, vault, forfeitOldShares);
        __after(user);

        if (
            _before[user].shareOf > 0 && _before[user].vaultOf != _after[user].vaultOf
                && (countSetVaultOf != 1 || countSetSharesOf == 0)
        ) {
            _checkInvariant(user);
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

    function deposit(address to, uint256 amount) public virtual override resetVars(to) returns (uint256 assets) {
        __before(to);

        assets = super.deposit(to, amount);

        __after(to);

        _checkInvariant(to);
    }

    function withdraw(address from, address to, uint256 amount)
        public
        virtual
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

        _checkInvariant(from);
        _checkInvariant(to);
    }

    function fullWithdraw(address from, address to)
        public
        virtual
        override
        resetVars(from)
        resetVars(to)
        returns (uint256 assets)
    {
        __before(from);
        __before(to);

        assets = super.fullWithdraw(from, to);

        __after(from);
        __after(to);

        _checkInvariant(from);
        _checkInvariant(to);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        resetVars(from)
        resetVars(to)
        returns (bool success)
    {
        __before(from);
        __before(to);

        success = super.transferFrom(from, to, amount);

        __after(from);
        __after(to);

        _checkInvariant(from);
        _checkInvariant(to);
    }

    function _checkInvariant(address account) internal {
        if (_before[account].vaultOf != _after[account].vaultOf) {
            emit InvariantViolatedEvent(
                VAULTS_04,
                _before[account].shareOf,
                _after[account].shareOf,
                _before[account].vaultOf,
                _after[account].vaultOf,
                countSetVaultOf,
                countSetSharesOf
            );
            assert(false);
            revert InvariantViolatedError(
                VAULTS_04,
                _before[account].shareOf,
                _after[account].shareOf,
                _before[account].vaultOf,
                _after[account].vaultOf,
                countSetVaultOf,
                countSetSharesOf
            );
        }
    }

    function getAdapterToId(address adapter) public view returns (bytes32 id) {
        return adapterToIdMap.get(adapter);
    }
}
