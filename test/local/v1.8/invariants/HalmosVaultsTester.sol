// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {ERC4626Mock as ERC4626OpenZeppelin} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Deploy} from "@script/Deploy.sol";

import {MockERC4626 as ERC4626Solmate} from "@solmate/src/test/utils/mocks/MockERC4626.sol";
import {ERC20 as ERC20Solmate} from "@solmate/src/tokens/ERC20.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

import {NonTransferrableRebasingTokenVaultGhost} from "@test/mocks/NonTransferrableRebasingTokenVaultGhost.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {SizeFactoryMock} from "@test/mocks/SizeFactoryMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";

import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";

/// @custom:halmos --flamegraph --early-exit --invariant-depth 2
contract HalmosVaultsTester is Test, PropertiesConstants, PropertiesSpecifications {
    uint256 private constant USDC_INITIAL_BALANCE = 1_000e6;

    NonTransferrableRebasingTokenVault private token;
    USDC private usdc;
    IPool private variablePool;
    SizeFactoryMock private sizeFactory;

    address[3] private users = [USER1, USER2, USER3];

    constructor() {
        usdc = new USDC(address(this));
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);

        sizeFactory = new SizeFactoryMock(address(this));

        token = new NonTransferrableRebasingTokenVaultGhost();
        token.initialize(
            ISizeFactory(address(sizeFactory)),
            variablePool,
            usdc,
            address(this),
            string.concat("Size ", usdc.name(), " Vault"),
            string.concat("sv", usdc.symbol()),
            usdc.decimals()
        );

        AaveAdapter aaveAdapter = new AaveAdapter(token, variablePool, usdc);
        token.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        token.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(token, usdc);
        token.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);

        address vault1 = address(new ERC4626OpenZeppelin(address(usdc)));
        address vault2 = address(new ERC4626Solmate(ERC20Solmate(address(usdc)), "Vault", "VAULT"));

        token.setVaultAdapter(vault1, bytes32("ERC4626Adapter"));
        token.setVaultAdapter(vault2, bytes32("ERC4626Adapter"));

        for (uint256 i = 0; i < users.length; i++) {
            usdc.mint(users[i], USDC_INITIAL_BALANCE);
            sizeFactory.setMarket(users[i], true);
            targetSender(users[i]);
        }

        targetContract(address(token));
        targetContract(address(usdc));
    }

    function invariant_VAULTS_01() public view {
        uint256 sumBalanceOf = 0;
        for (uint256 i = 0; i < users.length; i++) {
            sumBalanceOf += token.balanceOf(users[i]);
        }
        assertLe(sumBalanceOf, token.totalSupply(), VAULTS_01);
    }

    function invariant_VAULTS_02_04() public pure {
        // we're interested in hitting assertion failures in `NonTransferrableRebasingTokenVaultGhost`, so we create a dummy invariant
        assertTrue(true, string.concat(VAULTS_02, " / ", VAULTS_04));
    }

    // This fails if users can directly donate USDC to the `token` contract
    // function invariant_VAULTS_03() public view {
    //     assertEq(usdc.balanceOf(address(token)), 0, VAULTS_03);
    // }
}
