// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/market/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IMorphoChainlinkOracleV2} from "@src/oracle/adapters/morpho/IMorphoChainlinkOracleV2.sol";
import {IPriceFeedV1_7_1} from "@src/oracle/v1.7.1/IPriceFeedV1_7_1.sol";

/// @title PriceFeedMorphoChainlinkOracleV2
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///           using a Morpho Chainlink Oracle V2
///         Note: since the oracle configuration is hardcoded, the deployment parameters should be chosen carefully
///         Note: this price feed is supposed to be only used on mainnet
/// @dev `decimals` must be 18 to comply with Size contracts
contract PriceFeedMorphoChainlinkOracleV2 is IPriceFeedV1_7_1 {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    uint256 public immutable scaleFactor;
    IMorphoChainlinkOracleV2 public immutable morphoOracle;
    /* solhint-enable */

    constructor(IMorphoChainlinkOracleV2 _morphoOracle) {
        if (address(_morphoOracle) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        morphoOracle = _morphoOracle;
        scaleFactor = _morphoOracle.SCALE_FACTOR();
    }

    function getPrice() external view override returns (uint256) {
        return morphoOracle.price() / scaleFactor;
    }

    function description() external pure override returns (string memory) {
        return "PriceFeedMorphoChainlinkOracleV2";
    }
}
