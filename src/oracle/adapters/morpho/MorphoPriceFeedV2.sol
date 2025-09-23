// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";

/// @title MorphoPriceFeedV2
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice This contract returns the price of 1 `baseToken` in terms of `quoteToken` scaled to `decimals` using a Morpho oracle
contract MorphoPriceFeedV2 is IPriceFeed {
    /* solhint-disable */
    uint256 public immutable decimals;
    IOracle public immutable oracle;
    uint256 public immutable scaleDivisor;
    /* solhint-enable */

    constructor(uint256 _decimals, IOracle _oracle, uint8 _baseTokenDecimals, uint8 _quoteTokenDecimals) {
        if (address(_oracle) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (36 + _quoteTokenDecimals - _baseTokenDecimals < _decimals) {
            revert Errors.INVALID_DECIMALS(SafeCast.toUint8(_decimals));
        }

        decimals = _decimals;
        oracle = _oracle;
        scaleDivisor = 10 ** (36 + _quoteTokenDecimals - _baseTokenDecimals - _decimals);
    }

    function getPrice() external view override returns (uint256) {
        uint256 price = oracle.price();
        return price / scaleDivisor;
    }
}
