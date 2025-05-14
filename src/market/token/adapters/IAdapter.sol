// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IAdapter {
    /// @notice Returns the total supply of the vault
    /// @param vault The address of the vault
    /// @return The total supply of the vault
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
    /// @return The amount of assets deposited
    /// @dev Requires underlying to be approved to the adapter first
    function deposit(address vault, address to, uint256 amount) external returns (uint256);

    /// @notice Withdraws assets from the vault
    /// @param vault The address of the vault
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of assets to withdraw
    /// @return The amount of assets withdrawn
    function withdraw(address vault, address from, address to, uint256 amount) external returns (uint256);

    /// @notice Transfers assets from one account to another in the same vault
    /// @dev Requires underlying to be transferred to the adapter first
    /// @param vault The address of the vault
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of assets to transfer
    function transferFrom(address vault, address from, address to, uint256 amount) external;

    /// @notice Returns the price per share of the vault
    /// @param vault The address of the vault
    /// @return The price per share of the vault, in RAY
    function pricePerShare(address vault) external view returns (uint256);

    /// @notice Returns the asset of the vault
    /// @param vault The address of the vault
    /// @return The asset of the vault
    function getAsset(address vault) external view returns (address);
}
