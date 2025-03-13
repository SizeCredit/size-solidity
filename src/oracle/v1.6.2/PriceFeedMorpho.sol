// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol";
import {IOracle} from "@src/oracle/v1.5.1/adapters/morpho/IOracle.sol";
import {MorphoPriceFeed} from "@src/oracle/v1.5.1/adapters/morpho/MorphoPriceFeed.sol";
import {IPriceFeedV1_6_2} from "@src/oracle/v1.6.2/IPriceFeedV1_6_2.sol";

/// @title PriceFeedMorpho
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///           using a Morpho oracle
/// @dev `decimals` must be 18 to comply with Size contracts
///      `sequencerUptimeFeed` can be null for unsupported networks
///      In case the sequencer is down, `getPrice` reverts (see `ChainlinkSequencerUptimeFeed`)
contract PriceFeedMorpho is IPriceFeedV1_6_2 {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    ChainlinkSequencerUptimeFeed public immutable chainlinkSequencerUptimeFeed;
    MorphoPriceFeed public immutable morphoPriceFeed;
    /* solhint-enable */

    constructor(
        AggregatorV3Interface sequencerUptimeFeed,
        IOracle morphoOracle,
        IERC20Metadata baseToken,
        IERC20Metadata quoteToken
    ) {
        chainlinkSequencerUptimeFeed = new ChainlinkSequencerUptimeFeed(sequencerUptimeFeed);
        morphoPriceFeed = new MorphoPriceFeed(decimals, morphoOracle, baseToken, quoteToken);
    }

    function getPrice() external view override returns (uint256) {
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();
        return morphoPriceFeed.getPrice();
    }

    function description() external view override returns (string memory) {
        return string.concat(
            "PriceFeedMorpho | (",
            morphoPriceFeed.baseToken().symbol(),
            "/",
            morphoPriceFeed.quoteToken().symbol(),
            ") (Chainlink)"
        );
    }
}
