// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UserView} from "@src/libraries/UserLibrary.sol";
import {Deploy} from "@test/Deploy.sol";

abstract contract BeforeAfter is Deploy {
    struct Vars {
        UserView user;
        uint256 senderCollateralAmount;
        uint256 senderBorrowAmount;
    }

    Vars _before;
    Vars _after;

    function __before() internal {
        _before.user = size.getUserView(msg.sender);
        _before.senderCollateralAmount = weth.balanceOf(msg.sender);
        _before.senderBorrowAmount = usdc.balanceOf(msg.sender);
    }

    function __after() internal {
        _after.user = size.getUserView(msg.sender);
        _after.senderCollateralAmount = weth.balanceOf(msg.sender);
        _after.senderBorrowAmount = usdc.balanceOf(msg.sender);
    }
}
