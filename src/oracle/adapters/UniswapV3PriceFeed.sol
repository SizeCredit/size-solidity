// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

/// @title UniswapV3PriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice This contract returns the price of 1 `baseToken` in terms of `quoteToken` scaled to `decimals` using Uniswap V3 TWAPs
/// @dev UniswapV3 TWAPs can be manipulated and, as such, this price feed should not be the primary oracle. See https://blog.uniswap.org/uniswap-v3-oracles
contract UniswapV3PriceFeed is IPriceFeed {
    /* solhint-disable */
    uint256 public immutable decimals;
    IERC20Metadata public immutable baseToken;
    IERC20Metadata public immutable quoteToken;
    IUniswapV3Factory public immutable uniswapV3Factory;
    uint32 public immutable twapWindow;
    uint24 public immutable feeTier;
    IUniswapV3Pool public immutable pool;
    /* solhint-enable */

    constructor(
        uint256 _decimals,
        IERC20Metadata _baseToken,
        IERC20Metadata _quoteToken,
        IUniswapV3Factory _uniswapV3Factory,
        uint32 _twapWindow,
        uint24 _feeTier
    ) {
        if (
            address(_baseToken) == address(0) || address(_quoteToken) == address(0)
                || address(_uniswapV3Factory) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }
        if (address(_baseToken) == address(_quoteToken)) {
            revert Errors.INVALID_TOKEN(address(_quoteToken));
        }
        if (_twapWindow == 0) {
            revert Errors.NULL_AMOUNT();
        }
        if (IUniswapV3Factory(_uniswapV3Factory).feeAmountTickSpacing(_feeTier) == 0) {
            revert Errors.INVALID_FEE_TIER();
        }

        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(
                address(_uniswapV3Factory), PoolAddress.getPoolKey(address(_baseToken), address(_quoteToken), _feeTier)
            )
        );
        decimals = _decimals;
        uniswapV3Factory = _uniswapV3Factory;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        twapWindow = _twapWindow;
        feeTier = _feeTier;
    }

    function getPrice() public view override returns (uint256) {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = twapWindow;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 tick = SafeCast.toInt24(tickCumulativesDelta / int56(uint56(twapWindow)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(twapWindow)) != 0)) tick--;

        uint128 inAmount = SafeCast.toUint128(10 ** baseToken.decimals());

        uint256 quoteAmount = OracleLibrary.getQuoteAtTick(tick, inAmount, address(baseToken), address(quoteToken));
        return quoteAmount * 10 ** decimals / 10 ** quoteToken.decimals();
    }
}
