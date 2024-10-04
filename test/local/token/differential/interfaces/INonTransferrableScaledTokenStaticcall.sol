// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface INonTransferrableScaledTokenStaticcall {
    function allowance(address, address spender) external returns (uint256);

    function scaledBalanceOf(address account) external returns (uint256);

    function balanceOf(address account) external returns (uint256);

    function scaledTotalSupply() external returns (uint256);

    function totalSupply() external returns (uint256);

    function liquidityIndex() external returns (uint256);
}
