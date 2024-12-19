// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Math} from "@src/libraries/Math.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IPriceFeedV1_5_1} from "@src/oracle/v1.5.1/IPriceFeedV1_5_1.sol";
import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/v1.5.1/adapters/UniswapV3PriceFeed.sol";

/// @title PriceFeedUniswapV3TWAPChainlink
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///         using Uniswap V3 for `base` and a PriceFeedV1_5_1 for `quote`
/// @dev `decimals` must be 18 to comply with Size contracts
///      `sequencerUptimeFeed` can be null for unsupported networks
///      In case the sequencer is down, `getPrice` reverts (see `ChainlinkSequencerUptimeFeed`)
///      This oracle should only be used for assets that are not supported by Chainlink
contract PriceFeedUniswapV3TWAPChainlink is IPriceFeed {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    ChainlinkSequencerUptimeFeed public immutable chainlinkSequencerUptimeFeed;
    UniswapV3PriceFeed public immutable basePriceFeed;
    PriceFeed public immutable quotePriceFeed;
    /* solhint-enable */

    constructor(
        AggregatorV3Interface sequencerUptimeFeed,
        PriceFeedParams memory basePriceFeedParams,
        PriceFeedParams memory quotePriceFeedParams
    ) {
        chainlinkSequencerUptimeFeed = new ChainlinkSequencerUptimeFeed(sequencerUptimeFeed);
        basePriceFeed = new UniswapV3PriceFeed(
            decimals,
            basePriceFeedParams.baseToken,
            quotePriceFeedParams.quoteToken,
            basePriceFeedParams.uniswapV3Pool,
            basePriceFeedParams.twapWindow,
            basePriceFeedParams.averageBlockTime
        );
        quotePriceFeed = new PriceFeed(quotePriceFeedParams);
    }

    function getPrice() external view override returns (uint256) {
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();

        uint256 basePrice = basePriceFeed.getPrice();
        uint256 quotePrice = quotePriceFeed.getPrice();

        return Math.mulDivDown(basePrice, 10 ** decimals, quotePrice);
    }
}
