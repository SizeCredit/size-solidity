// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Withdraw, WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

library VariableLibrary {
    using SafeERC20 for IERC20Metadata;
    using Withdraw for State;

    function depositBorrowToken(State storage state, address, /*from*/ uint256 wad, address onBehalfOf) public {
        address asset = address(state._general.borrowAsset);
        uint256 amount = ConversionLibrary.wadToAmountDown(wad, state._general.borrowAsset.decimals());

        // unwrap borrowAsset (e.g. szUSDC) to borrowToken (e.g. USDC) from `msg.sender` to `address(this)`
        state.executeWithdraw(
            WithdrawParams({token: address(state._general.borrowAsset), amount: amount, to: address(this)})
        );

        state._general.borrowAsset.forceApprove(address(state._general.variablePool), amount);
        state._general.variablePool.supply(asset, amount, onBehalfOf, 0);
    }

    function withdrawBorrowToken(State storage state, address to, uint256 wad) public {
        address asset = address(state._general.borrowAsset);
        uint256 amount = ConversionLibrary.wadToAmountDown(wad, state._general.borrowAsset.decimals());

        // TODO: FROB won't have permission to withdraw because `depositBorrowToken` is called with `onBehalfOf`
        state._general.variablePool.withdraw(asset, amount, to);
    }
}
