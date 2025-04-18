// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/market/SizeStorage.sol";

/// @title DepositTokenLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains functions for interacting with underlying tokens
/// @dev Mints and burns 1:1 Size deposit tokens in exchange for underlying tokens
library DepositTokenLibrary {
    using SafeERC20 for IERC20Metadata;

    /// @notice Deposit underlying collateral token to the Size protocol
    /// @param state The state struct
    /// @param from The address from which the underlying collateral token is transferred
    /// @param to The address to which the Size deposit token is minted
    /// @param amount The amount of underlying collateral token to deposit
    function depositUnderlyingCollateralToken(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(state.data.underlyingCollateralToken);
        underlyingCollateralToken.safeTransferFrom(from, address(this), amount);
        state.data.collateralToken.mint(to, amount);
    }

    /// @notice Withdraw underlying collateral token from the Size protocol
    /// @param state The state struct
    /// @param from The address from which the Size deposit token is burned
    /// @param to The address to which the underlying collateral token is transferred
    /// @param amount The amount of underlying collateral token to withdraw
    function withdrawUnderlyingCollateralToken(State storage state, address from, address to, uint256 amount)
        external
    {
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(state.data.underlyingCollateralToken);
        state.data.collateralToken.burn(from, amount);
        underlyingCollateralToken.safeTransfer(to, amount);
    }

    /// @notice Deposit underlying borrow token to the Size protocol
    /// @dev The underlying borrow token is deposited to the borrowTokenVault,
    ///        and the corresponding Size borrow token is minted.
    ///      The underlying tokens are held by the borrowTokenVault contract
    /// @param state The state struct
    /// @param from The address from which the underlying borrow token is transferred
    /// @param to The address to which the Size borrow token is minted
    /// @param amount The amount of underlying borrow token to deposit
    function depositUnderlyingBorrowTokenToVault(State storage state, address from, address to, uint256 amount)
        external
    {
        state.data.underlyingBorrowToken.safeTransferFrom(from, address(this), amount);
        state.data.underlyingBorrowToken.forceApprove(address(state.data.borrowTokenVault), amount);
        state.data.borrowTokenVault.deposit(from, to, amount);
    }

    /// @notice Withdraw underlying borrow token from the Size protocol
    /// @dev The underlying borrow token is withdrawn from the borrowTokenVault,
    ///        and the corresponding Size borrow token is burned.
    ///      The underlying tokens are transferred from the borrowTokenVault contract `from` account to the `to` account
    /// @param state The state struct
    /// @param from The address from which the Size borrow token is burned
    /// @param to The address to which the underlying borrow token is transferred
    /// @param amount The amount of underlying borrow token to withdraw
    function withdrawUnderlyingTokenFromVault(State storage state, address from, address to, uint256 amount) external {
        state.data.borrowTokenVault.withdraw(from, to, amount);
    }
}
