// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {Deploy} from "@test/Deploy.sol";
import {Properties} from "./Properties.sol";
import "@crytic/properties/contracts/util/Hevm.sol";

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Deploy, PropertiesConstants, Properties {
    address internal owner;
    address internal protocolVault;
    address internal feeRecipient;

    function setup() internal override {
        owner = address(this);

        setup(owner, address(size), owner);
        address[] memory users = new address[](3);
        users[0] = USER1;
        users[1] = USER2;
        users[2] = USER3;
        for(uint256 i = 0; i < users.length; i++) {
            usdc.mint(users[i], 100_000e6);

            hevm.prank(users[i]);
            weth.deposit{value: 100e18}();
        }
    }

    function deposit(address token, uint256 amount) public {
        token = uint160(token) % 2 == 0 ? address(weth) : address(usdc);
        amount = between(amount, 0, IERC20Metadata(token).balanceOf(msg.sender));

        hevm.prank(msg.sender);
        size.deposit(DepositParams({token: token, amount: amount}));

        if(token == address(weth)) {
            eq(size.getUserView(msg.sender).collateralAmount, amount, DEPOSIT_01);
        }
        else {
            // @audit BUG
            eq(size.getUserView(msg.sender).borrowAmount, amount, DEPOSIT_01);
        }
    }
}
