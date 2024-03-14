// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAaveOracle} from "@aave/interfaces/IAaveOracle.sol";
import {Math} from "@src/libraries/Math.sol";

import {IPriceFeed} from "./IPriceFeed.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title VariablePoolPriceFeed
/// @notice A contract that provides the price of an asset in terms of another asset by interacting with the Variable Pool Price Feed
/// @dev The price is calculated as `base / quote`. Example configuration:
///      _base: ETH/USD feed
///      _quote: USDC/USD feed
///      _decimals: 18
///      answer: ETH/USDC in 1e18
contract VariablePoolPriceFeed is IPriceFeed {
    /* solhint-disable immutable-vars-naming */
    IAaveOracle public immutable aaveOracle;
    address public immutable base;
    uint8 public immutable baseDecimals;
    address public immutable quote;
    uint8 public immutable quoteDecimals;
    uint8 public immutable decimals;
    /* solhint-enable immutable-vars-naming */

    constructor(
        address _aaveOracle,
        address _base,
        uint8 _baseDecimals,
        address _quote,
        uint8 _quoteDecimals,
        uint8 _decimals
    ) {
        if (_aaveOracle == address(0) || _base == address(0) || _quote == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        if (_decimals == 0 || _decimals > 18) {
            revert Errors.INVALID_DECIMALS(_decimals);
        }

        if (_baseDecimals == 0 || _baseDecimals > 18 || _quoteDecimals == 0 || _quoteDecimals > 18) {
            revert Errors.INVALID_DECIMALS(_baseDecimals);
        }

        aaveOracle = IAaveOracle(_aaveOracle);
        base = _base;
        baseDecimals = _baseDecimals;
        quote = _quote;
        quoteDecimals = _quoteDecimals;
        decimals = _decimals;
    }

    function getPrice() external view returns (uint256) {
        uint256 basePrice = aaveOracle.getAssetPrice(base);
        uint256 quotePrice = aaveOracle.getAssetPrice(quote);
        return Math.mulDivDown(
            _scalePrice(basePrice, baseDecimals, decimals),
            10 ** decimals,
            _scalePrice(quotePrice, quoteDecimals, decimals)
        );
    }

    function _scalePrice(uint256 _price, uint8 _priceDecimals, uint8 _decimals) internal pure returns (uint256) {
        if (_priceDecimals < _decimals) {
            return _price * (10 ** uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / (10 ** uint256(_priceDecimals - _decimals));
        } else {
            return _price;
        }
    }
}
