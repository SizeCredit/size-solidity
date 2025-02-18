// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Math} from "@src/market/libraries/Math.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/v1.5.1/adapters/UniswapV3PriceFeed.sol";
import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

/// @title PriceFeedUniswapV3TWAPChainlink
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///           using Uniswap V3 for `base` and a IPriceFeedV1_5_1 for `quote`
///         The price is defined as `base * quote`
///         For example, this can be used to calculate the price of an ABC token for the ABC/USDC pair through
///           ABC/WETH via UniswapV3PriceFeed and WETH/USDC via IPriceFeedV1_5_1, ie, ABC/USDC = ABC/WETH * WETH/USDC
/// @dev `decimals` must be 18 to comply with Size contracts
///      `sequencerUptimeFeed` can be null for unsupported networks
///      In case the sequencer is down, `getPrice` reverts (see `ChainlinkSequencerUptimeFeed`)
///      This oracle should only be used for assets that are not supported by Chainlink
contract PriceFeedUniswapV3TWAPChainlink is IPriceFeedV1_5_2 {
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
            // other parameters of basePriceFeedParams are unused
            basePriceFeedParams.baseToken,
            basePriceFeedParams.quoteToken,
            basePriceFeedParams.uniswapV3Pool,
            basePriceFeedParams.twapWindow,
            basePriceFeedParams.averageBlockTime
        );

        quotePriceFeed = new PriceFeed(quotePriceFeedParams); // uses 18 decimals
    }

    function getPrice() external view override returns (uint256) {
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();

        uint256 basePrice = basePriceFeed.getPrice();
        uint256 quotePrice = quotePriceFeed.getPrice();

        return Math.mulDivDown(basePrice, quotePrice, 10 ** decimals);
    }

    function description() external view override returns (string memory) {
        return string.concat(
            "PriceFeedUniswapV3TWAPChainlink | (",
            basePriceFeed.baseToken().symbol(),
            "/",
            basePriceFeed.quoteToken().symbol(),
            ") (Uniswap v3 TWAP) * ((",
            quotePriceFeed.base().description(),
            ") / (",
            quotePriceFeed.quote().description(),
            ")) (PriceFeed)"
        );
    }
}
