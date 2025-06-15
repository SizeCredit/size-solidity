// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IAdapter
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Interface for the adapter
interface IAdapter {
    error InsufficientAssets(address vault, uint256 assets, uint256 amount);

    /// @notice Returns the total supply of the vault
    /// @param vault The address of the vault
    /// @return The total supply of the vault, including assets that cannot be withdrawn.
    function totalSupply(address vault) external view returns (uint256);

    /// @notice Returns the balance of the account
    /// @param vault The address of the vault
    /// @param account The address of the account
    /// @return The balance of the account
    function balanceOf(address vault, address account) external view returns (uint256);

    /// @notice Deposits assets into the vault
    /// @param vault The address of the vault
    /// @param to The address of the recipient
    /// @param amount The amount of assets to deposit
    /// @return assets The amount of assets given to the user. Can be lower than the deposited amount due to rounding, fees, etc
    /// @dev Requires underlying to be transferred to the adapter first
    function deposit(address vault, address to, uint256 amount) external returns (uint256 assets);

    /// @notice Withdraws assets from the vault
    /// @param vault The address of the vault
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of assets to withdraw
    /// @return assets The amount of assets withdrawn. Can be lower than the requested amount due to rounding, fees, etc
    function withdraw(address vault, address from, address to, uint256 amount) external returns (uint256 assets);

    /// @notice Withdraws all assets from the vault and sets shares to zero
    /// @param vault The address of the vault
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @return assets The amount of assets withdrawn.
    function fullWithdraw(address vault, address from, address to) external returns (uint256 assets);

    /// @notice Transfers assets from one account to another in the same vault
    /// @param vault The address of the vault
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of assets to transfer
    function transferFrom(address vault, address from, address to, uint256 amount) external;

    /// @notice Validates the vault
    /// @param vault The address of the vault
    /// @dev This function is used to validate the vault, including whether the underlying token is the same as the NonTransferrableRebasingTokenVault's underlying token
    function validate(address vault) external;
}
