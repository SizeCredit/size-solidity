// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "@aave/interfaces/IPool.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";
import {Events} from "@src/libraries/Events.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {Deposit, DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";
import {UserProxy} from "@src/proxy/UserProxy.sol";

library VariableLibrary {
    using SafeERC20 for IERC20Metadata;
    using Withdraw for State;
    using Deposit for State;

    function getUserProxy(State storage state, address user) public returns (UserProxy) {
        if (address(state._fixed.users[user].proxy) != address(0)) {
            return state._fixed.users[user].proxy;
        }
        UserProxy userProxy = UserProxy(payable(Clones.clone(state._variable.userProxyImplementation)));
        emit Events.CreateUserProxy(user, address(userProxy));
        userProxy.initialize(address(this));
        state._fixed.users[user].proxy = userProxy;
        return userProxy;
    }

    function getUserProxyAddress(State storage state, address user) public returns (address) {
        return address(getUserProxy(state, user));
    }

    function depositBorrowToken(State storage state, address, /*from*/ uint256 wad, address /*onBehalfOf*/ ) public {
        address asset = address(state._general.borrowAsset);
        uint256 amount = ConversionLibrary.wadToAmountUp(wad, state._general.borrowAsset.decimals());

        // unwrap borrowToken (e.g. szUSDC) to borrowAsset (e.g. USDC) from `msg.sender` to `address(this)`
        state.executeWithdraw(
            WithdrawParams({token: address(state._general.borrowAsset), amount: amount, to: address(this)})
        );

        state._general.borrowAsset.forceApprove(address(state._general.variablePool), amount);
        state._general.variablePool.supply(asset, amount, address(this), 0);
    }

    function withdrawBorrowToken(State storage state, address to, uint256 wad) public {
        address asset = address(state._general.borrowAsset);
        uint256 amount = ConversionLibrary.wadToAmountDown(wad, state._general.borrowAsset.decimals());

        state._general.variablePool.withdraw(asset, amount, address(this));

        state._general.borrowAsset.forceApprove(address(this), amount);
        state.executeDeposit(
            DepositParams({token: address(state._general.borrowAsset), amount: amount, to: to}), address(this)
        );
    }

    function borrowFromVariablePool(
        State storage state,
        address borrower,
        uint256 collateralAmountWad,
        uint256 borrowAmountWad
    ) public {
        address collateralAsset = address(state._general.collateralAsset);
        uint256 collateralAmount =
            ConversionLibrary.wadToAmountUp(collateralAmountWad, state._general.collateralAsset.decimals());
        address borrowAsset = address(state._general.borrowAsset);
        uint256 borrowAmount = ConversionLibrary.wadToAmountDown(borrowAmountWad, state._general.borrowAsset.decimals());

        UserProxy userProxy = getUserProxy(state, borrower);

        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](2);

        // unwrap collateralToken (e.g. szETH) to collateralAsset (e.g. WETH) from `borrower` to `address(this)`
        state.executeWithdraw(
            WithdrawParams({token: address(state._general.collateralAsset), amount: collateralAmount, to: address(this)}),
            borrower
        );

        // supply collateral asset
        state._general.collateralAsset.forceApprove(address(state._general.variablePool), collateralAmount);
        state._general.variablePool.supply(collateralAsset, collateralAmount, address(userProxy), 0);

        // borrow
        targets[0] = address(state._general.variablePool);
        data[0] = abi.encodeCall(IPool.borrow, (borrowAsset, borrowAmount, 2, 0, address(userProxy)));

        // transfer
        targets[1] = address(state._general.borrowAsset);
        data[1] = abi.encodeCall(IERC20.transfer, (borrower, borrowAmount));

        userProxy.proxy(targets, data);
    }
}
