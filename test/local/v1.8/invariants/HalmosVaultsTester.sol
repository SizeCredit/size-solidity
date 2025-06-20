// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {ERC4626Mock as ERC4626OpenZeppelin} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Deploy} from "@script/Deploy.sol";

import {MockERC4626 as ERC4626Solady} from "@solady/test/utils/mocks/MockERC4626.sol";
import {MockERC4626 as ERC4626Solmate} from "@solmate/src/test/utils/mocks/MockERC4626.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

import {NonTransferrableRebasingTokenVaultGhost} from "@test/mocks/NonTransferrableRebasingTokenVaultGhost.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {SizeFactoryMock} from "@test/mocks/SizeFactoryMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

/// @custom:halmos --flamegraph --early-exit --invariant-depth 2
contract HalmosVaultsTester is Test {
    NonTransferrableRebasingTokenVault private token;
    USDC private usdc;
    IPool private variablePool;
    SizeFactoryMock private sizeFactory;

    constructor() {
        usdc = new USDC(address(this));
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);

        sizeFactory = new SizeFactoryMock(address(this));

        token = NonTransferrableRebasingTokenVault(
            address(
                new ERC1967Proxy(
                    address(new NonTransferrableRebasingTokenVaultGhost()),
                    abi.encodeCall(
                        NonTransferrableRebasingTokenVault.initialize,
                        (
                            ISizeFactory(address(sizeFactory)),
                            variablePool,
                            usdc,
                            address(this),
                            string.concat("Size ", usdc.name(), " Vault"),
                            string.concat("sv", usdc.symbol()),
                            usdc.decimals()
                        )
                    )
                )
            )
        );

        AaveAdapter aaveAdapter = new AaveAdapter(token, variablePool, usdc);
        token.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        token.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(token, usdc);
        token.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);

        address vault1 = address(new ERC4626Solady(address(usdc), "Vault", "VAULT", true, 0));
        address vault2 = address(new ERC4626OpenZeppelin(address(usdc)));
        address vault3 = address(new ERC4626Solmate(ERC20(address(usdc)), "Vault3", "VAULT3"));

        token.setVaultAdapter(vault1, bytes32("ERC4626Adapter"));
        token.setVaultAdapter(vault2, bytes32("ERC4626Adapter"));
        token.setVaultAdapter(vault3, bytes32("ERC4626Adapter"));
    }

    function invariant_dummy() public view {
        // we're interested in hitting assertion failures in `NonTransferrableRebasingTokenVaultGhost`, so we create a dummy invariant
        assertEq(1, 1);
    }
}
