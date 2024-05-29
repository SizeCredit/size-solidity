// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

interface IUnoswapRouter {
    function unoswapTo(address recipient, address srcToken, uint256 amount, uint256 minReturn, address pool)
        external
        payable
        returns (uint256 returnAmount);
}
