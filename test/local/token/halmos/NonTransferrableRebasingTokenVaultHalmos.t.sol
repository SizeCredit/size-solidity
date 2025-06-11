// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Test} from "forge-std/Test.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {SizeFactoryMock} from "@test/local/token/halmos/SizeFactoryMock.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";

import {ERC4626Mock as ERC4626OpenZeppelin} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {MockERC4626 as ERC4626Solady} from "@solady/test/utils/mocks/MockERC4626.sol";
import {MockERC4626 as ERC4626Solmate} from "@solmate/src/test/utils/mocks/MockERC4626.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";

/// @custom:halmos --solver-timeout-assertion 0
contract NonTransferrableRebasingTokenVaultHalmosTest is
    SymTest,
    Test,
    PropertiesSpecifications,
    PropertiesConstants
{
    NonTransferrableRebasingTokenVault public target;
    SizeFactoryMock public sizeFactory;
    USDC public underlying;
    PoolMock public pool;
    ISize public market1;
    ISize public market2;
    address public vaultSolady;
    address public vaultOpenZeppelin;
    address public vaultSolmate;
    address[3] public users = [USER1, USER2, USER3];

    function setUp() public {
        underlying = new USDC(address(this));
        pool = new PoolMock();
        sizeFactory = new SizeFactoryMock(address(this), address(market2));

        vaultSolady = address(new ERC4626Solady(address(underlying), "Vault", "VAULT", true, 0));
        vaultOpenZeppelin = address(new ERC4626OpenZeppelin(address(underlying)));
        vaultSolmate = address(new ERC4626Solmate(ERC20(address(underlying)), "Vault3", "VAULT3"));

        target = NonTransferrableRebasingTokenVault(
            address(
                new ERC1967Proxy(
                    address(new NonTransferrableRebasingTokenVault()),
                    abi.encodeCall(
                        NonTransferrableRebasingTokenVault.initialize,
                        (
                            ISizeFactory(address(sizeFactory)),
                            IPool(address(pool)),
                            underlying,
                            address(this),
                            "Test Vault Token",
                            "TVT",
                            underlying.decimals()
                        )
                    )
                )
            )
        );

        AaveAdapter aaveAdapter = new AaveAdapter(target, IPool(address(pool)), underlying);
        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(target, underlying);

        target.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        target.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));
        target.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);
        target.setVaultAdapter(vaultSolady, bytes32("ERC4626Adapter"));
        target.setVaultAdapter(vaultOpenZeppelin, bytes32("ERC4626Adapter"));
        target.setVaultAdapter(vaultSolmate, bytes32("ERC4626Adapter"));

        for (uint256 i = 0; i < users.length; i++) {
            underlying.mint(users[i], INITIAL_BALANCE);
            underlying.approve(address(target), type(uint256).max);
        }

        targetContract(address(target));
    }

    /// @custom:halmos --invariant-depth 10
    function invariant_VAULTS_01() public view {
        uint256 sumBalanceOf = 0;
        for (uint256 i = 0; i < users.length; i++) {
            sumBalanceOf += target.balanceOf(users[i]);
        }

        assertEq(target.totalSupply(), sumBalanceOf, VAULTS_01);
    }
}
