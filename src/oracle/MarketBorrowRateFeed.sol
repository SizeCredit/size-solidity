// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMarketBorrowRateFeed} from "./IMarketBorrowRateFeed.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

contract MarketBorrowRateFeed is IMarketBorrowRateFeed {
    IPool public immutable pool;
    IERC20Metadata public immutable asset;

    constructor(
        address _pool,
        address _asset
    ) {
        if (_pool == address(0) || _asset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        pool = IPool(_pool);
        asset = IERC20Metadata(_asset);
    }


    function getMarketBorrowRate() external view override returns (uint256) {
        return 
        ConversionLibrary.rayToWadDown(
        pool.getReserveData(address(asset)).currentVariableBorrowRate
        );
    }
}
