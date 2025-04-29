// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {
    DEFAULT_VAULT,
    NonTransferrableRebasingTokenVaultBase,
    Storage
} from "@src/market/token/NonTransferrableRebasingTokenVaultBase.sol";

library AaveAdapter {
    using SafeERC20 for IERC20Metadata;

    function totalSupply(Storage storage s, address /*vault*/ ) internal view returns (uint256) {
        IAToken aToken = IAToken(s.aavePool.getReserveData(address(s.underlyingToken)).aTokenAddress);
        return aToken.balanceOf(address(this));
    }

    function balanceOf(Storage storage s, address vault, address account) internal view returns (uint256) {
        return _unscale(s, vault, s.scaledBalanceOf[account]);
    }

    function deposit(Storage storage s, address vault, address, /* from*/ address to, uint256 amount)
        internal
        returns (uint256 assets)
    {
        IAToken aToken = IAToken(s.aavePool.getReserveData(address(s.underlyingToken)).aTokenAddress);

        uint256 sharesBefore = aToken.scaledBalanceOf(address(this));

        s.underlyingToken.forceApprove(address(s.aavePool), amount);
        s.aavePool.supply(address(s.underlyingToken), amount, address(this), 0);

        uint256 shares = aToken.scaledBalanceOf(address(this)) - sharesBefore;
        assets = _unscale(s, vault, shares);

        s.scaledTotalSupply += shares;
        s.scaledBalanceOf[to] += shares;
    }

    function withdraw(Storage storage s, address vault, address from, address to, uint256 amount)
        internal
        returns (uint256 assets)
    {
        uint256 balance = balanceOf(s, vault, from);
        bool fullWithdraw = amount == balance;
        IAToken aToken = IAToken(s.aavePool.getReserveData(address(s.underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        s.aavePool.withdraw(address(s.underlyingToken), amount, to);

        uint256 shares = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));
        assets = _unscale(s, vault, shares);

        if (s.scaledBalanceOf[from] < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balance, amount);
        }

        if (fullWithdraw) {
            uint256 dust = s.scaledBalanceOf[from] - shares;
            s.scaledBalanceOf[from] = 0;
            s.scaledBalanceOf[Ownable2StepUpgradeable(address(this)).owner()] += dust;
        } else {
            s.scaledBalanceOf[from] -= shares;
        }
        s.scaledTotalSupply -= shares;
    }

    function transferFrom(Storage storage s, address vault, address from, address to, uint256 value) internal {
        IAToken aToken = IAToken(s.aavePool.getReserveData(address(s.underlyingToken)).aTokenAddress);
        if (s.underlyingToken.balanceOf(address(aToken)) < value) {
            revert NonTransferrableRebasingTokenVaultBase.InsufficientTotalAssets(
                DEFAULT_VAULT, s.underlyingToken.balanceOf(address(aToken)), value
            );
        }

        uint256 shares = Math.mulDivDown(value, WadRayMath.RAY, pricePerShare(s, vault));

        if (s.scaledBalanceOf[from] < shares) {
            revert IERC20Errors.ERC20InsufficientBalance(from, balanceOf(s, vault, from), value);
        }

        s.scaledBalanceOf[from] -= shares;
        s.scaledBalanceOf[to] += shares;
    }

    function _unscale(Storage storage s, address vault, uint256 scaledAmount) internal view returns (uint256) {
        return Math.mulDivDown(scaledAmount, pricePerShare(s, vault), WadRayMath.RAY);
    }

    function pricePerShare(Storage storage s, address /*vault*/ ) internal view returns (uint256) {
        return s.aavePool.getReserveNormalizedIncome(address(s.underlyingToken));
    }

    function getAsset(Storage storage s, address /*vault*/ ) internal view returns (address) {
        return address(s.underlyingToken);
    }
}
