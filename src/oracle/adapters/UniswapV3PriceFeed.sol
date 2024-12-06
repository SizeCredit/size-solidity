// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/interfaces/IUniswapV3Factory.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title UniswapV3PriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
contract UniswapV3PriceFeed is IPriceFeed {
    uint256 public immutable decimals;

    address public immutable baseToken;
    address public immutable quoteToken;
    uint32 public immutable twapWindow;

    uint24[] public feeTiers;
    constructor(uint256 _decimals) {
        decimals = _decimals;
    }
     
    function getPrice() external view override returns (uint256) {
        revert("Not implemented");
    }

}