// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

library NonTransferrableRebasingTokenVaultLibrary {
    function createNonTransferrableRebasingTokenVault(
        address implementation,
        address owner,
        IPool variablePool,
        IERC20Metadata underlyingBorrowToken
    ) external returns (NonTransferrableRebasingTokenVault token) {
        token = NonTransferrableRebasingTokenVault(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(
                        NonTransferrableRebasingTokenVault.initialize,
                        (
                            ISizeFactory(address(this)),
                            variablePool,
                            underlyingBorrowToken,
                            owner,
                            string.concat("Size ", underlyingBorrowToken.name(), " Vault"),
                            string.concat("sv", underlyingBorrowToken.symbol()),
                            underlyingBorrowToken.decimals()
                        )
                    )
                )
            )
        );
    }
}
