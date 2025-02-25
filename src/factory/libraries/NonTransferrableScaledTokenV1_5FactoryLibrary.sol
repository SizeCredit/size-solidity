// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {NonTransferrableScaledTokenV1_5} from "@src/market/token/NonTransferrableScaledTokenV1_5.sol";

library NonTransferrableScaledTokenV1_5FactoryLibrary {
    function createNonTransferrableScaledTokenV1_5(
        address implementation,
        address owner,
        IPool variablePool,
        IERC20Metadata underlyingBorrowToken
    ) external returns (NonTransferrableScaledTokenV1_5 token) {
        token = NonTransferrableScaledTokenV1_5(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(
                        NonTransferrableScaledTokenV1_5.initialize,
                        (
                            ISizeFactory(address(this)),
                            variablePool,
                            underlyingBorrowToken,
                            owner,
                            string.concat("Size Scaled ", underlyingBorrowToken.name(), " (v1.5)"),
                            string.concat("sa", underlyingBorrowToken.symbol()),
                            underlyingBorrowToken.decimals()
                        )
                    )
                )
            )
        );
    }
}
