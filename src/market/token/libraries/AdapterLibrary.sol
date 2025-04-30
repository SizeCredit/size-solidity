// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {NTRTVStorage} from "@src/market/token/NonTransferrableRebasingTokenVaultBase.sol";
import {AaveAdapter} from "@src/market/token/libraries/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/libraries/ERC4626Adapter.sol";

enum Adapter {
    Aave,
    ERC4626
}

struct VaultAdapterFunctions {
    function(NTRTVStorage storage, address) internal view returns (uint256) totalSupply;
    function(NTRTVStorage storage, address, address) internal view returns (uint256) balanceOf;
    function(NTRTVStorage storage, address, address, address, uint256) internal  returns (uint256) deposit;
    function(NTRTVStorage storage, address, address, address, uint256) internal  returns (uint256) withdraw;
    function(NTRTVStorage storage, address, address, address, uint256) internal transferFrom;
    function(NTRTVStorage storage, address) internal view returns (uint256) pricePerShare;
    function(NTRTVStorage storage, address) internal view returns (address) getAsset;
}

library AdapterLibrary {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    function fns(NTRTVStorage storage s, address vault)
        internal
        view
        returns (VaultAdapterFunctions memory functions)
    {
        (bool exists, uint256 adapter) = s.vaultToAdapterMap.tryGet(vault);

        if (!exists) {
            // should never happen
            revert Errors.INVALID_VAULT(vault);
        } else if (adapter == uint256(Adapter.Aave)) {
            functions = VaultAdapterFunctions({
                totalSupply: AaveAdapter.totalSupply,
                balanceOf: AaveAdapter.balanceOf,
                deposit: AaveAdapter.deposit,
                withdraw: AaveAdapter.withdraw,
                transferFrom: AaveAdapter.transferFrom,
                pricePerShare: AaveAdapter.pricePerShare,
                getAsset: AaveAdapter.getAsset
            });
        } else if (adapter == uint256(Adapter.ERC4626)) {
            functions = VaultAdapterFunctions({
                totalSupply: ERC4626Adapter.totalSupply,
                balanceOf: ERC4626Adapter.balanceOf,
                deposit: ERC4626Adapter.deposit,
                withdraw: ERC4626Adapter.withdraw,
                transferFrom: ERC4626Adapter.transferFrom,
                pricePerShare: ERC4626Adapter.pricePerShare,
                getAsset: ERC4626Adapter.getAsset
            });
        } else {
            // should never happen
            revert Errors.INVALID_ADAPTER(uint256(adapter));
        }
    }

    function totalSupply(NTRTVStorage storage s, address vault) internal view returns (uint256) {
        return fns(s, vault).totalSupply(s, vault);
    }

    function balanceOf(NTRTVStorage storage s, address vault, address account) internal view returns (uint256) {
        return fns(s, vault).balanceOf(s, vault, account);
    }

    function deposit(NTRTVStorage storage s, address vault, address from, address to, uint256 amount)
        internal
        returns (uint256)
    {
        return fns(s, vault).deposit(s, vault, from, to, amount);
    }

    function withdraw(NTRTVStorage storage s, address vault, address from, address to, uint256 amount)
        internal
        returns (uint256)
    {
        return fns(s, vault).withdraw(s, vault, from, to, amount);
    }

    function transferFrom(NTRTVStorage storage s, address vault, address from, address to, uint256 amount) internal {
        return fns(s, vault).transferFrom(s, vault, from, to, amount);
    }

    function pricePerShare(NTRTVStorage storage s, address vault) internal view returns (uint256) {
        return fns(s, vault).pricePerShare(s, vault);
    }

    function getAsset(NTRTVStorage storage s, address vault) internal view returns (address) {
        return fns(s, vault).getAsset(s, vault);
    }
}
