// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UserView} from "@src/libraries/UserLibrary.sol";
import {Deploy} from "@test/Deploy.sol";

abstract contract BeforeAfter is Deploy {
    struct Vars {
        UserView user;
        bool isLiquidatable;
        uint256 senderCollateralAmount;
        uint256 senderBorrowAmount;
        uint256 activeLoans;
        uint256 protocolBorrowAmount;
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
        _before.isLiquidatable = size.isLiquidatable(user);
        _before.senderCollateralAmount = weth.balanceOf(user);
        _before.senderBorrowAmount = usdc.balanceOf(user);
        _before.activeLoans = size.activeLoans();
        (_before.protocolBorrowAmount,,) = size.getProtocolVault();
    }

    function __after() internal {
        _after.user = size.getUserView(user);
        _after.isLiquidatable = size.isLiquidatable(user);
        _after.senderCollateralAmount = weth.balanceOf(user);
        _after.senderBorrowAmount = usdc.balanceOf(user);
        _after.activeLoans = size.activeLoans();
        (_after.protocolBorrowAmount,,) = size.getProtocolVault();
    }
}
