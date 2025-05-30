// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {
    DEFAULT_VAULT, NonTransferrableRebasingTokenVault
} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

contract AaveAdapter is Ownable, IAdapter {
    using SafeERC20 for IERC20Metadata;

    struct Vars {
        uint256 sharesBefore;
        uint256 assetsBefore;
        uint256 userSharesBefore;
    }

    // slither-disable-start uninitialized-state
    // slither-disable-start constable-states
    NonTransferrableRebasingTokenVault public immutable tokenVault;
    IPool public immutable aavePool;
    IERC20Metadata public immutable underlyingToken;
    IAToken public immutable aToken;
    // slither-disable-end constable-states
    // slither-disable-end uninitialized-state

    constructor(NonTransferrableRebasingTokenVault _tokenVault, IPool _aavePool, IERC20Metadata _underlyingToken)
        Ownable(address(_tokenVault))
    {
        if (
            address(_tokenVault) == address(0) || address(_aavePool) == address(0)
                || address(_underlyingToken) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }
        tokenVault = _tokenVault;
        aavePool = _aavePool;
        underlyingToken = _underlyingToken;
        aToken = IAToken(_aavePool.getReserveData(address(_underlyingToken)).aTokenAddress);
    }

    /// @inheritdoc IAdapter
    function totalSupply(address /*vault*/ ) external view returns (uint256) {
        return aToken.balanceOf(address(tokenVault));
    }

    /// @inheritdoc IAdapter
    function balanceOf(address vault, address account) public view returns (uint256) {
        return _unscale(vault, tokenVault.sharesOf(account));
    }

    /// @inheritdoc IAdapter
    function deposit(address vault, address to, uint256 amount) external onlyOwner returns (uint256 assets) {
        // slither-disable-next-line uninitialized-local
        Vars memory vars;
        vars.sharesBefore = aToken.scaledBalanceOf(address(tokenVault));
        vars.userSharesBefore = tokenVault.sharesOf(to);

        underlyingToken.forceApprove(address(aavePool), amount);
        aavePool.supply(address(underlyingToken), amount, address(tokenVault), 0);

        uint256 shares = aToken.scaledBalanceOf(address(tokenVault)) - vars.sharesBefore;
        assets = _unscale(vault, shares);

        tokenVault.setSharesOf(to, vars.userSharesBefore + shares);
    }

    /// @inheritdoc IAdapter
    function withdraw(address vault, address from, address to, uint256 amount)
        external
        onlyOwner
        returns (uint256 assets)
    {
        bool fullWithdraw = amount == balanceOf(vault, from);

        // slither-disable-next-line uninitialized-local
        Vars memory vars;
        vars.sharesBefore = aToken.scaledBalanceOf(address(tokenVault));
        vars.userSharesBefore = tokenVault.sharesOf(from);

        tokenVault.requestApprove(DEFAULT_VAULT, amount);
        IERC20Metadata(address(aToken)).safeTransferFrom(address(tokenVault), address(this), amount);
        // slither-disable-next-line unused-return
        aavePool.withdraw(address(underlyingToken), type(uint256).max, to);

        uint256 shares = vars.sharesBefore - aToken.scaledBalanceOf(address(tokenVault));
        assets = _unscale(vault, shares);

        if (vars.userSharesBefore < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), amount);
        }

        if (fullWithdraw) {
            tokenVault.setSharesOf(from, 0);
            tokenVault.setVaultDust(vault, tokenVault.vaultDust(vault) + vars.userSharesBefore - shares);
        } else {
            tokenVault.setSharesOf(from, vars.userSharesBefore - shares);
        }
    }

    /// @inheritdoc IAdapter
    function transferFrom(address vault, address from, address to, uint256 value) external onlyOwner {
        if (underlyingToken.balanceOf(address(aToken)) < value) {
            revert InsufficientTotalAssets(DEFAULT_VAULT, underlyingToken.balanceOf(address(aToken)), value);
        }

        uint256 shares = Math.mulDivDown(value, WadRayMath.RAY, pricePerShare(vault));
        if (tokenVault.sharesOf(from) < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), value);
        }
        tokenVault.setSharesOf(from, tokenVault.sharesOf(from) - shares);
        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @inheritdoc IAdapter
    function pricePerShare(address /*vault*/ ) public view returns (uint256) {
        return aavePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    /// @inheritdoc IAdapter
    function getAsset(address /*vault*/ ) external view returns (address) {
        return address(underlyingToken);
    }

    function _unscale(address vault, uint256 scaledAmount) internal view returns (uint256) {
        return Math.mulDivDown(scaledAmount, pricePerShare(vault), WadRayMath.RAY);
    }
}
