// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract TokenRecover {
    using SafeERC20 for IERC20;

    function _recover(IERC20 token, address to, uint256 amount) internal {
        token.safeTransfer(to, amount);
    }
}
