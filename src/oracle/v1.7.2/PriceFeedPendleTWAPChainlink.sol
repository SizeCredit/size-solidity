// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IPMarket} from "@pendle/contracts/interfaces/IPMarket.sol";
import {IPPrincipalToken} from "@pendle/contracts/interfaces/IPPrincipalToken.sol";
import {IStandardizedYield} from "@pendle/contracts/interfaces/IStandardizedYield.sol";

import {PendleChainlinkOracle} from "@pendle/contracts/oracles/PtYtLpOracle/chainlink/PendleChainlinkOracle.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {ChainlinkPriceFeed} from "@src/oracle/adapters/ChainlinkPriceFeed.sol";
import {IPriceFeedV1_7_2} from "@src/oracle/v1.7.2/IPriceFeedV1_7_2.sol";

/// @title PriceFeedPendleTWAPChainlink
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` PT asset in terms of a `quote` asset, scaled to 18 decimals,
///           using a Pendle oracle for the `base` to `underlying` asset and a ChainlinkPriceFeed for the `underlying` to `quote` asset
///         Note: this price feed is supposed to be only used on mainnet
/// @dev `decimals` must be 18 to comply with Size contracts
contract PriceFeedPendleTWAPChainlink is IPriceFeedV1_7_2 {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    PendleChainlinkOracle public immutable ptToUnderlyingPriceFeed;
    ChainlinkPriceFeed public immutable underlyingToQuotePriceFeed;

    /* solhint-enable */

    constructor(
        PendleChainlinkOracle _pendleOracle,
        AggregatorV3Interface _underlyingChainlinkOracle,
        AggregatorV3Interface _quoteChainlinkOracle,
        uint256 _underlyingStalePriceInterval,
        uint256 _quoteStalePriceInterval
    ) {
        if (
            address(_pendleOracle) == address(0) || address(_underlyingChainlinkOracle) == address(0)
                || address(_quoteChainlinkOracle) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }
        ptToUnderlyingPriceFeed = _pendleOracle;
        underlyingToQuotePriceFeed = new ChainlinkPriceFeed(
            decimals,
            _underlyingChainlinkOracle,
            _quoteChainlinkOracle,
            _underlyingStalePriceInterval,
            _quoteStalePriceInterval
        );
    }

    function getPrice() external view override returns (uint256) {
        // slither-disable-next-line unused-return
        (, int256 answer,,,) = ptToUnderlyingPriceFeed.latestRoundData();
        uint256 ptToUnderlyingPrice = SafeCast.toUint256(answer);
        uint256 underlyingToQuotePrice = underlyingToQuotePriceFeed.getPrice();
        return Math.mulDivDown(ptToUnderlyingPrice, underlyingToQuotePrice, 10 ** decimals);
    }

    function description() external view override returns (string memory) {
        IPMarket market = IPMarket(ptToUnderlyingPriceFeed.market());
        // slither-disable-next-line unused-return
        (IStandardizedYield sy, IPPrincipalToken pt,) = market.readTokens();
        // slither-disable-next-line unused-return
        (, address asset,) = sy.assetInfo();
        IERC20Metadata underlying = IERC20Metadata(asset);
        return string.concat(
            "PriceFeedPendleTWAPChainlink | (",
            pt.symbol(),
            "/",
            underlying.symbol(),
            ") * ((",
            underlyingToQuotePriceFeed.baseAggregator().description(),
            ")/(",
            underlyingToQuotePriceFeed.quoteAggregator().description(),
            "))"
        );
    }
}
