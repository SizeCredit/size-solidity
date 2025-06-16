// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";
import {ISizeV1_8} from "@src/market/interfaces/v1.8/ISizeV1_8.sol";

import {DepositOnBehalfOfParams, DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {SetVaultOnBehalfOfParams, SetVaultParams} from "@src/market/libraries/actions/SetVault.sol";
import {WithdrawOnBehalfOfParams, WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";

contract MaliciousERC4626ReentrancyGeneric is ERC4626, Ownable {
    ISize public size;
    bytes4 public operation;
    bool public forfeitOldShares;

    constructor(IERC20 underlying_, string memory name_, string memory symbol_)
        ERC4626(underlying_)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {}

    function setSize(ISize _size) external onlyOwner {
        size = _size;
    }

    function setForfeitOldShares(bool _forfeitOldShares) external onlyOwner {
        forfeitOldShares = _forfeitOldShares;
    }

    function setOperation(bytes4 _operation) external onlyOwner {
        bytes4[] memory operations = new bytes4[](4);
        operations[0] = ISizeV1_7.depositOnBehalfOf.selector;
        operations[1] = ISizeV1_7.withdrawOnBehalfOf.selector;
        operations[3] = ISizeV1_8.setVaultOnBehalfOf.selector;
        operations[4] = IERC20.approve.selector;
        operation = operations[uint256(uint32(_operation)) % operations.length];
    }

    function _reenter() internal {
        if (operation == ISizeV1_7.depositOnBehalfOf.selector) {
            size.depositOnBehalfOf(
                DepositOnBehalfOfParams({
                    params: DepositParams({
                        token: asset(),
                        amount: IERC20(asset()).balanceOf(address(this)),
                        to: address(this)
                    }),
                    onBehalfOf: owner()
                })
            );
        } else if (operation == ISizeV1_7.withdrawOnBehalfOf.selector) {
            size.withdrawOnBehalfOf(
                WithdrawOnBehalfOfParams({
                    params: WithdrawParams({token: asset(), amount: type(uint256).max, to: address(this)}),
                    onBehalfOf: owner()
                })
            );
        } else if (operation == ISizeV1_8.setVaultOnBehalfOf.selector) {
            size.setVaultOnBehalfOf(
                SetVaultOnBehalfOfParams({
                    params: SetVaultParams({vault: address(this), forfeitOldShares: forfeitOldShares}),
                    onBehalfOf: owner()
                })
            );
        } else if (operation == IERC20.approve.selector) {
            IERC20(asset()).approve(address(size), type(uint256).max);
        } else {
            revert Errors.NOT_SUPPORTED();
        }
    }
}
