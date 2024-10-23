// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface INonTransferrableScaledTokenCall {
    function mintScaled(address to, uint256 scaledAmount) external;

    function burnScaled(address from, uint256 scaledAmount) external;

    function transferFrom(address from, address to, uint256 value) external;

    function transfer(address to, uint256 value) external;

    function approve(address, uint256) external returns (bool);
}
