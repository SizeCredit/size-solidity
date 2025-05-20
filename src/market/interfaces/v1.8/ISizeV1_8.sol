// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LiquidateWithReplacementWithCollectionParams} from "@src/market/libraries/actions/LiquidateWithReplacement.sol";

/// @title ISizeV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for Size v1.8
interface ISizeV1_8 {
    /// @notice Same as `liquidateWithReplacement` but `withCollectionParams`
    function liquidateWithReplacementWithCollection(
        LiquidateWithReplacementWithCollectionParams memory withCollectionParams
    ) external payable returns (uint256 liquidatorProfitCollateralToken, uint256 liquidatorProfitBorrowToken);
}
