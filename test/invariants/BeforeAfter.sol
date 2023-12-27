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

    address internal user;
    Vars internal _before;
    Vars internal _after;

    modifier getUser() virtual {
        user = msg.sender;
        _;
    }

    function __before() internal {
        _before.user = size.getUserView(user);
        _before.senderCollateralAmount = weth.balanceOf(user);
        _before.senderBorrowAmount = usdc.balanceOf(user);
    }

    function __after() internal {
        _after.user = size.getUserView(user);
        _after.senderCollateralAmount = weth.balanceOf(user);
        _after.senderBorrowAmount = usdc.balanceOf(user);
    }
}
