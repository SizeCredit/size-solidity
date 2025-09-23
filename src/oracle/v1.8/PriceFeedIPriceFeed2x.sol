// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title PriceFeedIPriceFeed2x
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///         by calculating `base / quote`, using IPriceFeed only.
/// @dev `decimals` must be 18 to comply with Size contracts
///      Only networks without a sequencer are supported.
contract PriceFeedIPriceFeed2x is IPriceFeed {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    IPriceFeed public immutable base;
    IPriceFeed public immutable quote;
    /* solhint-enable */

    constructor(IPriceFeed base_, IPriceFeed quote_) {
        if (address(base_) == address(0) || address(quote_) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (base_.decimals() != quote_.decimals()) {
            revert Errors.INVALID_DECIMALS(SafeCast.toUint8(quote_.decimals()));
        }
        base = base_;
        quote = quote_;
    }

    function getPrice() external view override returns (uint256) {
        return Math.mulDivDown(base.getPrice(), quote.getPrice(), 10 ** decimals);
    }
}
