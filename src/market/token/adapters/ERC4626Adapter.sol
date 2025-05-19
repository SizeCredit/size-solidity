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

    // slither-disable-start uninitialized-state
    // slither-disable-start constable-states
    NonTransferrableRebasingTokenVault public immutable tokenVault;
    IERC20Metadata public immutable underlyingToken;
    // slither-disable-end constable-states
    // slither-disable-end uninitialized-state

    constructor(NonTransferrableRebasingTokenVault _tokenVault, IERC20Metadata _underlyingToken)
        Ownable(address(_tokenVault))
    {
        if (address(_tokenVault) == address(0) || address(_underlyingToken) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        tokenVault = _tokenVault;
        underlyingToken = _underlyingToken;
    }

    /// @inheritdoc IAdapter
    function totalSupply(address vault) external view returns (uint256) {
        return IERC4626(vault).maxWithdraw(address(tokenVault));
    }

    /// @inheritdoc IAdapter
    function balanceOf(address vault, address account) public view returns (uint256) {
        return IERC4626(vault).convertToAssets(tokenVault.sharesOf(account));
    }

    /// @inheritdoc IAdapter
    function deposit(address vault, address to, uint256 amount) external onlyOwner returns (uint256 assets) {
        underlyingToken.forceApprove(vault, amount);

        uint256 sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));

        // slither-disable-next-line unused-return
        IERC4626(vault).deposit(amount, address(tokenVault));

        uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - sharesBefore;
        assets = IERC4626(vault).convertToAssets(shares);

        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @inheritdoc IAdapter
    function withdraw(address vault, address from, address to, uint256 amount)
        external
        onlyOwner
        returns (uint256 assets)
    {
        bool fullWithdraw = amount == balanceOf(vault, from);
        uint256 sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
        uint256 assetsBefore = underlyingToken.balanceOf(address(this));

        tokenVault.requestApprove(vault, type(uint256).max);
        // slither-disable-next-line unused-return
        IERC4626(vault).withdraw(amount, address(this), address(tokenVault));

        tokenVault.requestApprove(vault, 0);

        uint256 shares = sharesBefore - IERC4626(vault).balanceOf(address(tokenVault));
        assets = underlyingToken.balanceOf(address(this)) - assetsBefore;

        underlyingToken.safeTransfer(to, assets);

        if (fullWithdraw) {
            uint256 dust = tokenVault.sharesOf(from) - shares;
            tokenVault.setSharesOf(from, 0);
            tokenVault.setVaultDust(vault, tokenVault.vaultDust(vault) + dust);
        } else {
            tokenVault.setSharesOf(from, tokenVault.sharesOf(from) - shares);
        }
    }

    /// @inheritdoc IAdapter
    function transferFrom(address vault, address from, address to, uint256 value) external onlyOwner {
        if (IERC4626(vault).totalAssets() < value) {
            revert InsufficientTotalAssets(address(vault), IERC4626(vault).totalAssets(), value);
        }

        uint256 shares = IERC4626(vault).convertToShares(value);

        if (tokenVault.sharesOf(from) < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), value);
        }

        tokenVault.setSharesOf(from, tokenVault.sharesOf(from) - shares);
        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @inheritdoc IAdapter
    function pricePerShare(address vault) public view returns (uint256) {
        return Math.mulDivDown(IERC4626(vault).totalAssets(), WadRayMath.RAY, IERC4626(vault).totalSupply());
    }

    /// @inheritdoc IAdapter
    function getAsset(address vault) external view returns (address) {
        return IERC4626(vault).asset();
    }
}
