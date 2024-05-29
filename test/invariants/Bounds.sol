// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

abstract contract Bounds {
    uint256 internal MAX_AMOUNT_USDC = 3 * 100_000e6;
    uint256 internal MAX_AMOUNT_WETH = 3 * 100e18;
    uint256 internal MAX_DURATION = 10 * 365 days;
    uint256 internal MIN_PRICE = 0.01e18;
    uint256 internal MAX_PRICE = 20_000e18;
    uint256 internal MAX_LIQUIDITY_INDEX_INCREASE_PERCENT = 1.05e18;
    uint256 internal MAX_PERCENT = 5e18;
    uint256 internal PERCENTAGE_OLD_CREDIT = 0.5e18;
}
