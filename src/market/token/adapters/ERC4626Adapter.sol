// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

contract ERC4626Adapter is Ownable, IAdapter {
    using SafeERC20 for IERC20Metadata;

    NonTransferrableRebasingTokenVault public immutable tokenVault;
    IERC20Metadata public immutable underlyingToken;

    constructor(NonTransferrableRebasingTokenVault _tokenVault, IERC20Metadata _underlyingToken)
        Ownable(address(_tokenVault))
    {
        tokenVault = _tokenVault;
        underlyingToken = _underlyingToken;
    }

    /// @notice Returns the totalSupply of assets deposited in the vault
    function totalSupply(address vault) external view returns (uint256) {
        return IERC4626(vault).maxWithdraw(address(tokenVault));
    }

    /// @notice Returns the balance of assets of an account in the vault
    function balanceOf(address vault, address account) public view returns (uint256) {
        return IERC4626(vault).convertToAssets(tokenVault.sharesOf(account));
    }

    /// @notice Deposits assets into the vault
    /// @dev Requires underlying to be transferred to the adapter first
    function deposit(address vault, address, /*from*/ address to, uint256 amount) external returns (uint256 assets) {
        underlyingToken.forceApprove(vault, amount);

        uint256 sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));

        // slither-disable-next-line unused-return
        IERC4626(vault).deposit(amount, address(tokenVault));

        uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - sharesBefore;
        assets = IERC4626(vault).convertToAssets(shares);

        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @notice Withdraws assets from the vault
    /// @dev Requires tokenVault to have approved to address(this) first
    function withdraw(address vault, address from, address to, uint256 amount) external returns (uint256 assets) {
        bool fullWithdraw = amount == balanceOf(vault, from);
        uint256 sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
        uint256 assetsBefore = underlyingToken.balanceOf(address(this));

        tokenVault.pullVaultTokens(vault, IERC4626(vault).previewWithdraw(amount));
        // slither-disable-next-line unused-return
        IERC4626(vault).withdraw(amount, address(this), address(this));

        uint256 shares = sharesBefore - IERC4626(vault).balanceOf(address(tokenVault));
        assets = underlyingToken.balanceOf(address(this)) - assetsBefore;

        underlyingToken.safeTransfer(to, assets);

        uint256 sharesBeforeFrom = tokenVault.sharesOf(from);

        if (fullWithdraw) {
            uint256 dust = sharesBeforeFrom - shares;
            uint256 dustBefore = tokenVault.vaultDust(vault);
            tokenVault.setSharesOf(from, 0);
            tokenVault.setVaultDust(vault, dustBefore + dust);
        } else {
            tokenVault.setSharesOf(from, sharesBeforeFrom - shares);
        }
    }

    /// @notice Transfers shares from one account to another from the same vault
    function transferFrom(address vault, address from, address to, uint256 value) external {
        if (IERC4626(vault).totalAssets() < value) {
            revert NonTransferrableRebasingTokenVault.InsufficientTotalAssets(
                address(vault), IERC4626(vault).totalAssets(), value
            );
        }

        uint256 shares = IERC4626(vault).convertToShares(value);

        if (tokenVault.sharesOf(from) < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), value);
        }

        tokenVault.setSharesOf(from, tokenVault.sharesOf(from) - shares);
        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @notice Returns the price per share of the vault
    function pricePerShare(address vault) public view returns (uint256) {
        return IERC4626(vault).convertToAssets(10 ** underlyingToken.decimals());
    }

    /// @notice Returns the asset of the vault
    function getAsset(address vault) external view returns (address) {
        return IERC4626(vault).asset();
    }
}
