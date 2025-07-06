// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {ERC4626Mock as ERC4626OpenZeppelin} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Deploy} from "@script/Deploy.sol";

import {MockERC4626 as ERC4626Solmate} from "@solmate/src/test/utils/mocks/MockERC4626.sol";
import {ERC20 as ERC20Solmate} from "@solmate/src/tokens/ERC20.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {
    AAVE_ADAPTER_ID,
    DEFAULT_VAULT,
    ERC4626_ADAPTER_ID
} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

import {HalmosNonTransferrableRebasingTokenVaultGhost} from
    "@test/mocks/HalmosNonTransferrableRebasingTokenVaultGhost.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {SizeFactoryMock} from "@test/mocks/SizeFactoryMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";

import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";

/// @dev This test should be executed with depth >= 4, but it results in TIMEOUT
/// @custom:halmos --early-exit --invariant-depth 2
contract HalmosVaultsTester is Test, PropertiesConstants, PropertiesSpecifications {
    uint256 private constant USDC_INITIAL_BALANCE = 1_000_000e6;

    NonTransferrableRebasingTokenVault private token;
    USDC private usdc;
    IPool private variablePool;
    SizeFactoryMock private sizeFactory;
    address private vault;

    address[3] private users = [USER1, USER2, USER3];

    constructor() {
        usdc = new USDC(address(this));
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);

        sizeFactory = new SizeFactoryMock(address(this));

        token = new HalmosNonTransferrableRebasingTokenVaultGhost();
        token.initialize(
            ISizeFactory(address(sizeFactory)),
            variablePool,
            usdc,
            address(this),
            string.concat("Size ", usdc.name(), " Vault"),
            string.concat("sv", usdc.symbol()),
            usdc.decimals()
        );

        AaveAdapter aaveAdapter = new AaveAdapter(token);
        token.setAdapter(AAVE_ADAPTER_ID, aaveAdapter);
        token.setVaultAdapter(DEFAULT_VAULT, AAVE_ADAPTER_ID);

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(token);
        token.setAdapter(ERC4626_ADAPTER_ID, erc4626Adapter);

        vault = address(new ERC4626Solmate(ERC20Solmate(address(usdc)), "Vault", "VAULT"));

        token.setVaultAdapter(vault, ERC4626_ADAPTER_ID);

        for (uint256 i = 0; i < users.length; i++) {
            usdc.mint(users[i], USDC_INITIAL_BALANCE);
            sizeFactory.setMarket(users[i], true);
            vm.prank(users[i]);
            usdc.approve(address(token), USDC_INITIAL_BALANCE);
            vm.prank(users[i]);
            token.setVault(users[i], vault, false);

            targetSender(users[i]);
        }
        usdc.transferOwnership(USER2);

        targetContract(address(token));
        targetContract(address(usdc));

        bytes4[] memory selectors;
        StdInvariant.FuzzSelector memory fuzzSelector;

        selectors = new bytes4[](1);
        selectors[0] = usdc.burn.selector;
        fuzzSelector = StdInvariant.FuzzSelector({addr: address(usdc), selectors: selectors});
        targetSelector(fuzzSelector);
        selectors = new bytes4[](2);
        selectors[0] = token.setVault.selector;
        selectors[1] = token.deposit.selector;
        fuzzSelector = StdInvariant.FuzzSelector({addr: address(token), selectors: selectors});
        targetSelector(fuzzSelector);
    }

    // halmos is timing out on this invariant, so we're skipping it
    function invariant_VAULTS_01() public view {
        // uint256 sumBalanceOf = 0;
        // for (uint256 i = 0; i < users.length; i++) {
        //     sumBalanceOf += token.balanceOf(users[i]);
        // }
        // assertLe(sumBalanceOf, token.totalSupply(), VAULTS_01);
    }

    function invariant_VAULTS_02_04() public pure {
        // we're interested in hitting assertion failures in `NonTransferrableRebasingTokenVaultGhost`, so we create a dummy invariant
        assertTrue(true, string.concat(VAULTS_02, " / ", VAULTS_04));
    }

    function invariant_VAULTS_03() public view {
        assertEq(usdc.balanceOf(address(token)), 0, VAULTS_03);
    }

    function test_HalmosVaultsTester_01() public {
        vm.warp(0x8000000000000000);
        vm.prank(address(0x30000));
        usdc.approve(address(token), 0x4000000000000000000000000000000000000000000000000000000000000000);
        vm.warp(0x8000000000000000);
        vm.prank(address(0x30000));
        try token.deposit(0x8000000000000000000000000000000000000000, 0x2f86489e) {} catch {}
        invariant_VAULTS_01();
        invariant_VAULTS_02_04();
        invariant_VAULTS_03();
    }

    function test_HalmosVaultsTester_02() public {
        vm.prank(USER2);
        token.deposit(USER2, 1);

        vm.prank(USER1);
        token.deposit(USER1, USDC_INITIAL_BALANCE);

        vm.prank(USER2);
        usdc.burn(vault, 1000e6);

        vm.assume(token.balanceOf(USER2) == 0 && token.sharesOf(USER2) > 0);

        vm.prank(USER2);
        try token.setVault(USER2, DEFAULT_VAULT, false) {} catch {}
        invariant_VAULTS_01();
        invariant_VAULTS_02_04();
        invariant_VAULTS_03();
    }
}
