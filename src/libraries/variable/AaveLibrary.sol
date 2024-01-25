// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IScaledBalanceToken} from "@aave/interfaces/IScaledBalanceToken.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {DataTypes} from "@aave/protocol/libraries/types/DataTypes.sol";

import {State} from "@src/SizeStorage.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice AaveLibrary: deposits and withdraws to Aave
/// keep track of the rewards for each depositor

/// [Unscaled tokens] are the actual ERC-20 tokens that represent a user's
/// balance in the Aave protocol. When a user deposits assets (USDC in our case)
/// into the Aave protocol, they receive an equivalent amount of unscaled
/// aTokens in return. Each user's unscaled aToken balance directly reflects
/// the number of tokens they have deposited.

/// [Scaled aTokens], on the other hand, are used to represent the proportion or
/// index of a user's deposited assets relative to the total assets in a liquidity pool.
/// They are a normalized representation of the user's share of the liquidity pool's
/// assets. Used as shares of rewards or incentives in relation to the total
/// liquidity supplied. The scaled aToken balance is calculated based on the user's
/// unscaled aToken balance and the total assets in the pool.
library AaveLibrary {
    using SafeERC20 for IERC20Metadata;

    function getAToken(State storage state) public view returns (IScaledBalanceToken) {
        address asset = address(state._general.borrowAsset);
        DataTypes.ReserveData memory data = state._general.variablePool.getReserveData(address(asset));
        return IScaledBalanceToken(data.aTokenAddress);
    }

    function getLiquidityIndexRAY(State storage state) public view returns (uint256) {
        address asset = address(state._general.borrowAsset);
        return state._general.variablePool.getReserveNormalizedIncome(asset);
    }

    /// @notice Returns the total amount of underlying assets held by the specified in decimals (not WAD)
    function balanceOfBorrowAssets(State storage state, address account) external view returns (uint256) {
        uint256 scaledDeposits = state._fixed.users[account].vpBorrowAssetScaledDeposits;
        uint256 liquidityIndexRAY = getLiquidityIndexRAY(state);
        // TODO round down
        return WadRayMath.rayMul(scaledDeposits, liquidityIndexRAY);
    }

    function transferScaledDeposits(State storage state, address from, address to, uint256 amount) external {
        state._fixed.users[from].vpBorrowAssetScaledDeposits -= amount;
        state._fixed.users[to].vpBorrowAssetScaledDeposits += amount;
    }

    function supplyBorrowAssets(State storage state, uint256 amount, address from, address to)
        external
        returns (uint256 scaledAmount)
    {
        address asset = address(state._general.borrowAsset);
        IScaledBalanceToken aToken = getAToken(state);

        // transfer to `address(this)`
        state._general.borrowAsset.safeTransferFrom(from, address(this), amount);

        // supply to Aave
        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));
        state._general.borrowAsset.forceApprove(address(state._general.variablePool), amount);
        state._general.variablePool.supply(asset, amount, address(this), 0);
        uint256 scaledBalanceAfter = aToken.scaledBalanceOf(address(this));

        // update scaled deposits
        scaledAmount = scaledBalanceAfter - scaledBalanceBefore;
        state._fixed.users[to].vpBorrowAssetScaledDeposits += scaledAmount;
    }

    function withdrawBorrowAssets(State storage state, uint256 amount, address from, address to)
        external
        returns (uint256 borrowAssetsReceived, uint256 scaledAmount)
    {
        address asset = address(state._general.borrowAsset);
        IScaledBalanceToken aToken = getAToken(state);

        // withdraw from Aave
        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));
        borrowAssetsReceived = state._general.variablePool.withdraw(asset, amount, to);
        uint256 scaledBalanceAfter = aToken.scaledBalanceOf(address(this));

        // update scaled deposits
        scaledAmount = scaledBalanceBefore - scaledBalanceAfter;
        state._fixed.users[from].vpBorrowAssetScaledDeposits -= scaledAmount;
    }
}
