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

import {IAaveAdapter} from "@src/market/token/adapters/IAaveAdapter.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {
    DEFAULT_VAULT, NonTransferrableRebasingTokenVault
} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

contract AaveAdapter is Ownable, IAaveAdapter {
    using SafeERC20 for IERC20Metadata;

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
    function totalSupply(address vault) external view returns (uint256) {
        if (tokenVault.getWhitelistedVaultAdapter(vault) != this) {
            revert Errors.INVALID_VAULT(vault);
        } else {
            return aToken.balanceOf(address(tokenVault));
        }
    }

    /// @inheritdoc IAdapter
    function balanceOf(address vault, address account) public view returns (uint256) {
        if (tokenVault.getWhitelistedVaultAdapter(vault) != this || tokenVault.vaultOf(account) != vault) {
            revert Errors.INVALID_VAULT(vault);
        } else {
            return _unscale(tokenVault.sharesOf(account));
        }
    }

    /// @inheritdoc IAdapter
    function deposit(address, /*vault*/ address to, uint256 amount) external onlyOwner returns (uint256 assets) {
        uint256 sharesBefore = aToken.scaledBalanceOf(address(tokenVault));
        uint256 userSharesBefore = tokenVault.sharesOf(to);

        underlyingToken.forceApprove(address(aavePool), amount);
        aavePool.supply(address(underlyingToken), amount, address(tokenVault), 0);

        uint256 shares = aToken.scaledBalanceOf(address(tokenVault)) - sharesBefore;
        assets = _unscale(shares);

        tokenVault.setSharesOf(to, userSharesBefore + shares);
    }

    /// @inheritdoc IAdapter
    /// @dev By withdrawing `type(uint256).max`, it is possible that the recipient receives amount +- 1 due to rounding
    function withdraw(address vault, address from, address to, uint256 amount)
        external
        onlyOwner
        returns (uint256 assets)
    {
        uint256 sharesBefore = aToken.scaledBalanceOf(address(tokenVault));
        uint256 userSharesBefore = tokenVault.sharesOf(from);

        tokenVault.requestAaveWithdraw(amount, to);

        uint256 shares = sharesBefore - aToken.scaledBalanceOf(address(tokenVault));
        assets = _unscale(shares);

        if (userSharesBefore < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), amount);
        }

        tokenVault.setSharesOf(from, userSharesBefore - shares);
    }

    /// @inheritdoc IAdapter
    function transferFrom(address vault, address from, address to, uint256 value) external onlyOwner {
        if (underlyingToken.balanceOf(address(aToken)) < value) {
            revert InsufficientAssets(DEFAULT_VAULT, underlyingToken.balanceOf(address(aToken)), value);
        }

        uint256 shares = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());
        if (tokenVault.sharesOf(from) < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(vault, from), value);
        }
        tokenVault.setSharesOf(from, tokenVault.sharesOf(from) - shares);
        tokenVault.setSharesOf(to, tokenVault.sharesOf(to) + shares);
    }

    /// @inheritdoc IAdapter
    function validate(address vault) external pure {
        if (vault != DEFAULT_VAULT) {
            revert Errors.INVALID_VAULT(vault);
        }
    }

    /// @inheritdoc IAaveAdapter
    function liquidityIndex() public view returns (uint256) {
        return aavePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    function _unscale(uint256 scaledAmount) private view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }
}
