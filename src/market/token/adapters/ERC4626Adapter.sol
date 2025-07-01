// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Math} from "@src/market/libraries/Math.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

contract ERC4626Adapter is Ownable, IAdapter {
    using SafeERC20 for IERC20Metadata;

    struct Vars {
        uint256 sharesBefore;
        uint256 assetsBefore;
        uint256 userSharesBefore;
    }

    // slither-disable-start uninitialized-state
    // slither-disable-start constable-states
    NonTransferrableRebasingTokenVault public immutable tokenVault;
    IERC20Metadata public immutable underlyingToken;
    // slither-disable-end constable-states
    // slither-disable-end uninitialized-state

    constructor(NonTransferrableRebasingTokenVault _tokenVault) Ownable(address(_tokenVault)) {
        tokenVault = _tokenVault;
        underlyingToken = _tokenVault.underlyingToken();
    }

    /// @inheritdoc IAdapter
    function totalSupply(address vault) external view returns (uint256) {
        if (tokenVault.getWhitelistedVaultAdapter(vault) != this) {
            revert Errors.INVALID_VAULT(vault);
        } else {
            return IERC4626(vault).convertToAssets(IERC4626(vault).balanceOf(address(tokenVault)));
        }
    }

    /// @inheritdoc IAdapter
    function balanceOf(address vault, address account) public view returns (uint256) {
        if (tokenVault.getWhitelistedVaultAdapter(vault) != this || tokenVault.vaultOf(account) != vault) {
            revert Errors.INVALID_VAULT(vault);
        } else {
            return IERC4626(vault).convertToAssets(tokenVault.sharesOf(account));
        }
    }

    /// @inheritdoc IAdapter
    function deposit(address vault, address to, uint256 amount) external onlyOwner returns (uint256 assets) {
        uint256 sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
        uint256 userSharesBefore = tokenVault.sharesOf(to);

        underlyingToken.forceApprove(vault, amount);
        // slither-disable-next-line unused-return
        IERC4626(vault).deposit(amount, address(tokenVault));

        uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - sharesBefore;
        assets = IERC4626(vault).convertToAssets(shares);

        tokenVault.setSharesOf(to, userSharesBefore + shares);
    }

    /// @inheritdoc IAdapter
    function withdraw(address vault, address from, address to, uint256 amount)
        external
        onlyOwner
        returns (uint256 assets)
    {
        uint256 userBalanceBefore = balanceOf(vault, from);
        if (userBalanceBefore < amount) {
            revert IERC20Errors.ERC20InsufficientBalance(from, userBalanceBefore, amount);
        }

        uint256 sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
        uint256 assetsBefore = underlyingToken.balanceOf(address(this));
        uint256 userSharesBefore = tokenVault.sharesOf(from);

        tokenVault.requestApprove(vault, type(uint256).max);
        // slither-disable-next-line unused-return
        IERC4626(vault).withdraw(amount, address(this), address(tokenVault));
        tokenVault.requestApprove(vault, 0);

        uint256 shares = sharesBefore - IERC4626(vault).balanceOf(address(tokenVault));
        assets = underlyingToken.balanceOf(address(this)) - assetsBefore;

        if (userSharesBefore < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, userBalanceBefore, amount);
        }

        underlyingToken.safeTransfer(to, assets);
        tokenVault.setSharesOf(from, userSharesBefore - shares);
    }

    /// @inheritdoc IAdapter
    function fullWithdraw(address vault, address from, address to) external onlyOwner returns (uint256 assets) {
        uint256 assetsBefore = underlyingToken.balanceOf(address(this));
        uint256 userSharesBefore = tokenVault.sharesOf(from);

        tokenVault.requestApprove(vault, type(uint256).max);
        // slither-disable-next-line unused-return
        IERC4626(vault).redeem(userSharesBefore, address(this), address(tokenVault));
        tokenVault.requestApprove(vault, 0);

        assets = underlyingToken.balanceOf(address(this)) - assetsBefore;

        underlyingToken.safeTransfer(to, assets);
        tokenVault.setSharesOf(from, 0);
    }

    /// @inheritdoc IAdapter
    function transferFrom(address vault, address from, address to, uint256 value) external onlyOwner {
        checkLiquidity(vault, value);

        uint256 shares = IERC4626(vault).convertToShares(value);

        if (tokenVault.sharesOf(from) < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), value);
        }

        tokenVault.setSharesOf(from, tokenVault.sharesOf(from) - shares);
        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @inheritdoc IAdapter
    function validate(address vault) external view {
        if (IERC4626(vault).asset() != address(underlyingToken)) {
            revert Errors.INVALID_VAULT(vault);
        }
    }

    /// @inheritdoc IAdapter
    function checkLiquidity(address vault, uint256 amount) public view {
        if (IERC4626(vault).maxWithdraw(address(tokenVault)) < amount) {
            revert InsufficientAssets(address(vault), IERC4626(vault).maxWithdraw(address(tokenVault)), amount);
        }
    }
}
