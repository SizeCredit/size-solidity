// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";
import {SetVaultOnBehalfOfParams, SetVaultParams} from "@src/market/libraries/actions/SetVault.sol";

contract MaliciousERC4626ReentrancyGeneric is ERC4626, Ownable {
    ISize public size;
    bytes4 public operation;

    constructor(IERC20 underlying_, string memory name_, string memory symbol_)
        ERC4626(underlying_)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {}

    function setSize(ISize _size) external onlyOwner {
        size = _size;
    }

    function setOperation(bytes4 _operation) external onlyOwner {
        bytes4[] memory operations = new bytes4[](10);
        operations[0] = ISizeV1_7.depositOnBehalfOf.selector;
        operations[1] = ISizeV1_7.withdrawOnBehalfOf.selector;
        operations[2] = ISizeV1_7.buyCreditLimitOnBehalfOf.selector;
        operations[3] = ISizeV1_7.sellCreditLimitOnBehalfOf.selector;
        operations[4] = ISizeV1_7.buyCreditMarketOnBehalfOf.selector;
        operations[5] = ISizeV1_7.sellCreditMarketOnBehalfOf.selector;
        operations[6] = ISizeV1_7.selfLiquidateOnBehalfOf.selector;
        operations[7] = ISizeV1_7.compensateOnBehalfOf.selector;
        operations[8] = ISizeV1_7.setUserConfigurationOnBehalfOf.selector;
        operations[9] = ISizeV1_7.setCopyLimitOrderConfigsOnBehalfOf.selector;
        operation = operations[uint256(uint32(_operation)) % operations.length];
    }
}
