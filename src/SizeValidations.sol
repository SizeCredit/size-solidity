// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ISize} from "./interfaces/ISize.sol";
import {SizeView} from "./SizeView.sol";

abstract contract SizeValidations is SizeView, ISize {
    function _validateUserHealthy(address account) internal {
        if (isLiquidatable(account)) {
            revert ISize.UserUnhealthy(account);
        }
    }
}
