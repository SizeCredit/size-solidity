// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IAdapter {
    function totalSupply(address vault) external view returns (uint256);
    function balanceOf(address vault, address account) external view returns (uint256);
    function deposit(address vault, address from, address to, uint256 amount) external returns (uint256);
    function withdraw(address vault, address from, address to, uint256 amount) external returns (uint256);
    function transferFrom(address vault, address from, address to, uint256 amount) external;
    function pricePerShare(address vault) external view returns (uint256);
    function getAsset(address vault) external view returns (address);
}
