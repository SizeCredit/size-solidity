// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IOracle} from "@src/oracle/adapters/morpho/IOracle.sol";

/// @title MorphoPriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice This contract returns the price of 1 `baseToken` in terms of `quoteToken` scaled to `decimals` using a Morpho oracle
contract MorphoPriceFeed is IPriceFeed {
    /* solhint-disable */
    uint256 public immutable decimals;
    IOracle public immutable oracle;
    IERC20Metadata public immutable baseToken;
    IERC20Metadata public immutable quoteToken;
    uint256 public immutable scaleDivisor;
    /* solhint-enable */

    constructor(uint256 _decimals, IOracle _oracle, IERC20Metadata _baseToken, IERC20Metadata _quoteToken) {
        if (address(_oracle) == address(0) || address(_baseToken) == address(0) || address(_quoteToken) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (address(_baseToken) == address(_quoteToken)) {
            revert Errors.INVALID_TOKEN(address(_quoteToken));
        }
        if (36 + _quoteToken.decimals() - _baseToken.decimals() < _decimals) {
            revert Errors.INVALID_DECIMALS(SafeCast.toUint8(_decimals));
        }

        decimals = _decimals;
        oracle = _oracle;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        scaleDivisor = 10 ** (36 + _quoteToken.decimals() - _baseToken.decimals() - _decimals);
    }

    function getPrice() external view override returns (uint256) {
        uint256 price = oracle.price();
        return price / scaleDivisor;
    }
}
