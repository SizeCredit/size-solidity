// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IPMarket} from "@pendle/contracts/interfaces/IPMarket.sol";
import {IPPYLpOracle} from "@pendle/contracts/interfaces/IPPYLpOracle.sol";

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title PendlePTPriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice This contract returns the price of 1 `PT` token in terms of the underlying `Asset` scaled to `decimals` using Pendle PT Oracles (https://docs.pendle.finance/Developers/Oracles/HowToIntegratePtAndLpOracle)
///         For example, on a sUSDE-29MAY2025 market, this contract returns the price of 1 `PT-sUSDE-29MAY2025` token in terms of `sUSDE`
/// @dev This contract increases the observation cardinality of the Pendle market if it is less than the desired
///      The observation cardinality needed is about `ceil(t / tau) + 1`, where `tau` is the time passing between two blocks (see https://reports.zellic.io/publications/beefy-uniswapv3/sections/observation-cardinality-observation-cardinality)
///      We adjust the desired cardinality by `OBSERVATION_CARDINALITY_MULTIPLIER_PERCENT` to account for the fact that block times are not constant
contract PendlePTPriceFeed is IPriceFeed {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    IPPYLpOracle public immutable pendlePyLpOracle;
    IPMarket public immutable pendleMarket;
    uint32 public immutable twapWindow;
    uint32 public immutable averageBlockTime;
    /* solhint-enable */

    uint256 private constant OBSERVATION_CARDINALITY_MULTIPLIER_PERCENT = 1.3e18;

    constructor(IPPYLpOracle _pendlePyLpOracle, IPMarket _pendleMarket, uint32 _twapWindow, uint32 _averageBlockTime) {
        if (address(_pendlePyLpOracle) == address(0) || address(_pendleMarket) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (_twapWindow == 0) {
            revert Errors.INVALID_TWAP_WINDOW();
        }
        if (_averageBlockTime == 0) {
            revert Errors.INVALID_AVERAGE_BLOCK_TIME();
        }

        pendlePyLpOracle = _pendlePyLpOracle;
        pendleMarket = _pendleMarket;
        twapWindow = _twapWindow;
        averageBlockTime = _averageBlockTime;

        (bool increaseCardinalityRequired,,) = _pendlePyLpOracle.getOracleState(address(pendleMarket), twapWindow);

        uint256 desiredCardinality = FixedPointMathLib.divUp(_twapWindow, _averageBlockTime) + 1;
        desiredCardinality = Math.mulDivUp(desiredCardinality, OBSERVATION_CARDINALITY_MULTIPLIER_PERCENT, PERCENT);
        uint16 observationCardinalityNext = SafeCast.toUint16(desiredCardinality);
        if (increaseCardinalityRequired) {
            _pendleMarket.increaseObservationsCardinalityNext(observationCardinalityNext);
        }
    }

    function getPrice() external view override returns (uint256) {
        return pendlePyLpOracle.getPtToAssetRate(address(pendleMarket), twapWindow);
    }
}
