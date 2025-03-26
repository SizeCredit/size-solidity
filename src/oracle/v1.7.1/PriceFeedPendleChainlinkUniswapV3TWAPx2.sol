// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Math} from "@src/market/libraries/Math.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPMarket} from "@pendle/contracts/interfaces/IPMarket.sol";
import {IPPYLpOracle} from "@pendle/contracts/interfaces/IPPYLpOracle.sol";

import {IPPrincipalToken} from "@pendle/contracts/interfaces/IPPrincipalToken.sol";
import {IStandardizedYield} from "@pendle/contracts/interfaces/IStandardizedYield.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PendlePTPriceFeed} from "@src/oracle/adapters/PendlePTPriceFeed.sol";
import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {PriceFeedChainlinkUniswapV3TWAPx2} from "@src/oracle/v1.5.2/PriceFeedChainlinkUniswapV3TWAPx2.sol";
import {IPriceFeedV1_7_1} from "@src/oracle/v1.7.1/IPriceFeedV1_7_1.sol";

/// @title PriceFeedChainlinkUniswapV3TWAPx2
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///           where `base` is a Pendle PT token, and `quote` uses Chainlink, with fallback using two Uniswap V3 TWAPs,
///           by multiplying the price of `base` and `quote`
///           For example, this can be used to calculate the price of PT-sUSDE-29MAY2025 in terms of USDC through PT-sUSDE-29MAY2025/sUSDE * sUSDE/USDC
/// @dev `decimals` must be 18 to comply with Size contracts
contract PriceFeedPendleChainlinkUniswapV3TWAPx2 is IPriceFeedV1_7_1 {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    PendlePTPriceFeed public immutable basePriceFeed;
    PriceFeedChainlinkUniswapV3TWAPx2 public immutable quotePriceFeed;
    /* solhint-enable */

    constructor(
        IPPYLpOracle basePendlePyLpOracle,
        IPMarket basePendleMarket,
        uint32 baseTwapWindow,
        uint32 baseAverageBlockTime,
        PriceFeedParams memory quoteChainlinkPriceFeedParams,
        PriceFeedParams memory quoteUniswapV3BasePriceFeedParams,
        PriceFeedParams memory quoteUniswapV3QuotePriceFeedParams
    ) {
        basePriceFeed =
            new PendlePTPriceFeed(basePendlePyLpOracle, basePendleMarket, baseTwapWindow, baseAverageBlockTime);
        quotePriceFeed = new PriceFeedChainlinkUniswapV3TWAPx2(
            quoteChainlinkPriceFeedParams, quoteUniswapV3BasePriceFeedParams, quoteUniswapV3QuotePriceFeedParams
        );
    }

    function getPrice() external view override returns (uint256) {
        uint256 basePrice = basePriceFeed.getPrice();
        uint256 quotePrice = quotePriceFeed.getPrice();

        return Math.mulDivDown(basePrice, quotePrice, 10 ** decimals);
    }

    function description() external view override returns (string memory) {
        (IStandardizedYield _SY, IPPrincipalToken _PT,) = basePriceFeed.pendleMarket().readTokens();
        (, address asset,) = _SY.assetInfo();
        string memory basePriceFeedDescription =
            string.concat("(", _PT.symbol(), " / ", IERC20Metadata(asset).symbol(), ") (Pendle)");
        return string.concat(
            "PriceFeedPendleChainlinkUniswapV3TWAPx2 | (",
            basePriceFeedDescription,
            ") * (",
            quotePriceFeed.description(),
            ")"
        );
    }
}
