// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
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
///      This contract increases the observation cardinality if it is less than the desired (see https://docs.uniswap.org/contracts/v3/reference/core/interfaces/pool/IUniswapV3PoolActions#increaseobservationcardinalitynext)
///      The observation cardinality needed is about `ceil(t / tau) + 1`, where `tau` is the time passing between two blocks (see https://reports.zellic.io/publications/beefy-uniswapv3/sections/observation-cardinality-observation-cardinality)
contract UniswapV3PriceFeed is IPriceFeed {
    /* solhint-disable */
    uint256 public immutable decimals;
    IERC20Metadata public immutable baseToken;
    IERC20Metadata public immutable quoteToken;
    IUniswapV3Factory public immutable uniswapV3Factory;
    IUniswapV3Pool public immutable uniswapV3Pool;
    uint32 public immutable twapWindow;
    uint32 public immutable averageBlockTime;
    /* solhint-enable */

    constructor(
        uint256 _decimals,
        IERC20Metadata _baseToken,
        IERC20Metadata _quoteToken,
        IUniswapV3Factory _uniswapV3Factory,
        IUniswapV3Pool _uniswapV3Pool,
        uint32 _twapWindow,
        uint32 _averageBlockTime
    ) {
        if (
            address(_baseToken) == address(0) || address(_quoteToken) == address(0)
                || address(_uniswapV3Factory) == address(0) || address(_uniswapV3Pool) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }
        if (address(_baseToken) == address(_quoteToken)) {
            revert Errors.INVALID_TOKEN(address(_quoteToken));
        }
        if (_twapWindow == 0) {
            revert Errors.INVALID_TWAP_WINDOW();
        }
        if (_averageBlockTime == 0) {
            revert Errors.INVALID_AVERAGE_BLOCK_TIME();
        }

        decimals = _decimals;
        uniswapV3Factory = _uniswapV3Factory;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        uniswapV3Pool = _uniswapV3Pool;
        twapWindow = _twapWindow;
        averageBlockTime = _averageBlockTime;

        // slither-disable-next-line unused-return
        (,,, uint16 cardinality,,,) = IUniswapV3Pool(_uniswapV3Pool).slot0();
        uint16 desiredCardinality = SafeCast.toUint16(FixedPointMathLib.divUp(_twapWindow, _averageBlockTime) + 1);
        if (cardinality < desiredCardinality) {
            uniswapV3Pool.increaseObservationCardinalityNext(desiredCardinality);
        }
    }

    function getPrice() public view override returns (uint256) {
        // slither-disable-next-line unused-return
        (int24 meanTick,) = OracleLibrary.consult(address(uniswapV3Pool), twapWindow);
        uint128 baseAmount = SafeCast.toUint128(10 ** baseToken.decimals());
        uint256 quoteAmount =
            OracleLibrary.getQuoteAtTick(meanTick, baseAmount, address(baseToken), address(quoteToken));
        return quoteAmount * 10 ** decimals / 10 ** quoteToken.decimals();
    }
}
