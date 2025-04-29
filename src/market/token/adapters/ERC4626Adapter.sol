// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {
    NonTransferrableRebasingTokenVaultBase,
    Storage
} from "@src/market/token/NonTransferrableRebasingTokenVaultBase.sol";

library ERC4626Adapter {
    using SafeERC20 for IERC20Metadata;

    function totalSupply(Storage storage, address vault) internal view returns (uint256) {
        return IERC4626(vault).maxWithdraw(address(this));
    }

    function balanceOf(Storage storage s, address vault, address account) internal view returns (uint256) {
        return IERC4626(vault).convertToAssets(s.sharesOf[account]);
    }

    function deposit(Storage storage s, address vault, address, /*from*/ address to, uint256 amount)
        internal
        returns (uint256 assets)
    {
        s.underlyingToken.forceApprove(vault, amount);

        uint256 sharesBefore = IERC4626(vault).balanceOf(address(this));

        // slither-disable-next-line unused-return
        IERC4626(vault).deposit(amount, address(this));

        uint256 shares = IERC4626(vault).balanceOf(address(this)) - sharesBefore;
        assets = IERC4626(vault).convertToAssets(shares);

        s.sharesOf[to] += shares;
    }

    function withdraw(Storage storage s, address vault, address from, address to, uint256 amount)
        internal
        returns (uint256 assets)
    {
        bool fullWithdraw = amount == balanceOf(s, vault, from);
        uint256 sharesBefore = IERC4626(vault).balanceOf(address(this));
        uint256 assetsBefore = s.underlyingToken.balanceOf(address(this));

        // slither-disable-next-line unused-return
        IERC4626(vault).withdraw(amount, address(this), address(this));

        uint256 shares = sharesBefore - IERC4626(vault).balanceOf(address(this));
        assets = s.underlyingToken.balanceOf(address(this)) - assetsBefore;

        s.underlyingToken.safeTransfer(to, assets);

        if (fullWithdraw) {
            uint256 dust = s.sharesOf[from] - shares;
            s.sharesOf[from] = 0;
            s.sharesOf[Ownable2StepUpgradeable(address(this)).owner()] += dust;
        } else {
            s.sharesOf[from] -= shares;
        }
    }

    function transferFrom(Storage storage s, address vault, address from, address to, uint256 value) internal {
        if (IERC4626(vault).totalAssets() < value) {
            revert NonTransferrableRebasingTokenVaultBase.InsufficientTotalAssets(
                address(vault), IERC4626(vault).totalAssets(), value
            );
        }

        uint256 shares = IERC4626(vault).convertToShares(value);

        if (s.sharesOf[from] < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(s, vault, from), value);
        }

        s.sharesOf[from] -= shares;
        s.sharesOf[to] += shares;
    }

    function pricePerShare(Storage storage s, address vault) internal view returns (uint256) {
        return IERC4626(vault).convertToAssets(10 ** s.underlyingToken.decimals());
    }

    function getAsset(Storage storage, address vault) internal view returns (address) {
        (bool success, bytes memory data) = vault.staticcall(abi.encodeWithSelector(IERC4626.asset.selector));
        if (!success) {
            revert Errors.INVALID_VAULT(vault);
        }
        return abi.decode(data, (address));
    }
}
