// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

contract NonTransferrableRebasingTokenVaultTest is BaseTest {
    NonTransferrableRebasingTokenVault public token;
    address user = address(0x10);
    address owner = address(0x20);
    USDC public underlying;
    IPool public pool;
    IAToken public aToken;

    uint256 public constant INITIAL_VAULT_ASSETS = 200e6;

    function setUp() public override {
        setupLocal(owner, feeRecipient);

        underlying = USDC(address(size.data().underlyingBorrowToken));
        pool = size.data().variablePool;
        token = size.data().borrowTokenVault;
        aToken = IAToken(pool.getReserveData(address(underlying)).aTokenAddress);

        _labels();

        // first deposit
        deal(address(underlying), address(alice), INITIAL_VAULT_ASSETS);
        vm.prank(alice);
        underlying.approve(address(vault), INITIAL_VAULT_ASSETS);
        vm.prank(alice);
        vault.deposit(INITIAL_VAULT_ASSETS, alice);
    }

    function test_NonTransferrableRebasingTokenVault_initialize() public view {
        assertEq(token.name(), "Size USD Coin Vault");
        assertEq(token.symbol(), "svUSDC");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(address(token.sizeFactory()), address(sizeFactory));
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableRebasingTokenVault_validation() public {
        NonTransferrableRebasingTokenVault implementation = new NonTransferrableRebasingTokenVault();
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        token = NonTransferrableRebasingTokenVault(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(
                        NonTransferrableRebasingTokenVault.initialize,
                        (
                            ISizeFactory(address(0)),
                            IPool(address(0)),
                            IERC20Metadata(address(0)),
                            owner,
                            "Test",
                            "TEST",
                            18
                        )
                    )
                )
            )
        );
    }

    function test_NonTransferrableRebasingTokenVault_upgrade() public {
        NonTransferrableRebasingTokenVault implementation = new NonTransferrableRebasingTokenVault();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.upgradeToAndCall(address(implementation), bytes(""));

        vm.prank(owner);
        token.upgradeToAndCall(address(implementation), bytes(""));
    }

    function test_NonTransferrableRebasingTokenVault_transferFrom_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED.selector, owner));
        vm.prank(owner);
        token.transferFrom(user, address(this), 50);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IAdapter.InsufficientAssets.selector, address(0), 0, 50));
        token.transferFrom(user, address(this), 50);

        uint256 deposit = 100;

        deal(address(underlying), address(size), deposit);
        vm.prank(address(size));
        underlying.approve(address(token), deposit);
        vm.prank(address(size));
        token.deposit(user, deposit);

        deal(address(underlying), address(aToken), 100);
        vm.prank(address(size));
        token.transferFrom(user, address(this), 50);

        vm.prank(address(owner));
        token.setVaultAdapter(address(vault), "ERC4626Adapter");
        vm.prank(address(size));
        token.setVault(user, address(vault), false);
        vm.prank(address(size));
        token.setVault(address(this), address(vault), false);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IAdapter.InsufficientAssets.selector, address(vault), deposit, 50e18));
        token.transferFrom(user, address(this), 50e18);

        deal(address(underlying), address(size), 100e18);
        vm.prank(address(size));
        underlying.approve(address(token), 100e18);
        vm.prank(address(size));
        token.deposit(user, 100e18);

        vm.prank(address(size));
        token.transferFrom(user, address(this), 50e18);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.transferFrom(address(0), address(this), 50e18);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(user, address(0), 50e18);
    }

    function test_NonTransferrableRebasingTokenVault_transfer() public {
        vm.prank(address(size));
        deal(address(token), address(size), 100);

        assertEq(token.balanceOf(address(size)), 100);
        assertEq(token.balanceOf(user), 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        vm.prank(address(size));
        token.transfer(user, 30);

        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(size)), 100);
    }

    function test_NonTransferrableRebasingTokenVault_totalSupply_1() public {
        deal(address(underlying), alice, 300);
        _deposit(alice, address(underlying), 300);
        assertEq(token.totalSupply(), 300);
    }

    function test_NonTransferrableRebasingTokenVault_allowance() public view {
        assertEq(token.allowance(user, address(this)), 0);
        assertEq(token.allowance(user, owner), 0);
        assertEq(token.allowance(user, address(size)), type(uint256).max);
    }

    function test_NonTransferrableRebasingTokenVault_approveReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.approve(address(this), 100);
    }

    function test_NonTransferrableRebasingTokenVault_deposit() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(address(size));
        token.deposit(address(0), 500);

        vm.prank(owner);
        deal(address(underlying), address(size), 1000);

        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, 1000);
        assertEq(token.balanceOf(user), 1000);
    }

    function test_NonTransferrableRebasingTokenVault_withdraw() public {
        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.withdraw(address(0), user, 500);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(address(size));
        token.withdraw(user, address(0), 500);

        vm.prank(owner);
        deal(address(underlying), address(size), 1000);

        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, 1000);
        vm.prank(address(size));
        token.withdraw(user, user, 500);
        assertEq(token.balanceOf(user), 500);
    }

    function test_NonTransferrableRebasingTokenVault_setVaultAdapter() public {
        assertTrue(token.isWhitelistedVault(DEFAULT_VAULT));
        assertTrue(!token.isWhitelistedVault(address(vault)));

        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");
        assertTrue(token.isWhitelistedVault(address(vault)));

        assertEq(token.getWhitelistedVaultsCount(), 2);
        (address vault, address adapter, bytes32 id) = token.getWhitelistedVault(0);
        assertEq(vault, DEFAULT_VAULT);
        assertTrue(adapter != address(0));
        assertEq(id, bytes32("AaveAdapter"));

        assertEq(address(token.getWhitelistedVaultAdapter(DEFAULT_VAULT)), adapter);
    }

    function test_NonTransferrableRebasingTokenVault_update_ERC4626Adapter() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new ERC4626Adapter(NonTransferrableRebasingTokenVault(address(0)), underlying);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new ERC4626Adapter(token, IERC20Metadata(address(0)));

        ERC4626Adapter adapter = new ERC4626Adapter(token, underlying);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        token.setAdapter(bytes32("ERC4626Adapter"), IAdapter(address(0)));

        vm.prank(owner);
        token.setAdapter(bytes32("ERC4626Adapter"), adapter);
    }

    function test_NonTransferrableRebasingTokenVault_update_AaveAdapter() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new AaveAdapter(NonTransferrableRebasingTokenVault(address(0)), pool, underlying);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new AaveAdapter(token, IPool(address(0)), underlying);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        new AaveAdapter(token, pool, IERC20Metadata(address(0)));

        AaveAdapter adapter = new AaveAdapter(token, pool, underlying);

        vm.prank(owner);
        token.setAdapter(bytes32("AaveAdapter"), adapter);
    }

    function test_NonTransferrableRebasingTokenVault_setVault_1() public {
        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        token.setVault(address(0), address(vault), false);

        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(alice, address(vault), false);
        assertEq(address(token.vaultOf(alice)), address(vault));
    }

    function testFuzz_NonTransferrableRebasingTokenVault_aave_deposit_withdraw_path(
        uint256 depositAmount,
        uint256 withdrawAmount,
        uint256 liquidityIndex
    ) public {
        depositAmount = bound(depositAmount, 1, 1e18);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);
        liquidityIndex = bound(liquidityIndex, 1e27, 1.5e27);

        deal(address(underlying), address(size), depositAmount);
        vm.prank(address(size));
        underlying.approve(address(token), depositAmount);

        vm.prank(address(size));
        token.deposit(user, depositAmount);
        assertEq(token.balanceOf(user), depositAmount, "deposit amount");

        _setLiquidityIndex(liquidityIndex);

        uint256 balanceBefore = underlying.balanceOf(user);

        vm.prank(address(size));
        token.withdraw(user, user, withdrawAmount);
        assertEq(underlying.balanceOf(user), balanceBefore + withdrawAmount, "withdraw amount");
    }

    function test_NonTransferrableRebasingTokenVault_aave_deposit_withdraw_path_concrete() public {
        testFuzz_NonTransferrableRebasingTokenVault_aave_deposit_withdraw_path(
            4658740278735764266672813707384099823332568,
            115792089237316195423570985008687907853269984665640564039457584007913129639934,
            373227715561
        );
    }

    function test_NonTransferrableRebasingTokenVault_vault_deposit_withdraw_path() public {
        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(user, address(vault), false);

        deal(address(underlying), address(size), 1000);
        vm.prank(address(size));
        underlying.approve(address(token), 1000);

        vm.prank(address(size));
        token.deposit(user, 1000);
        assertEq(token.balanceOf(user), 1000);

        vm.prank(address(size));
        token.withdraw(user, user, 500);
        assertEq(token.balanceOf(user), 500);
    }

    function test_NonTransferrableRebasingTokenVault_admin_removes_vault_after_deposits() public {
        _deposit(bob, address(underlying), 3000);
        assertEq(token.balanceOf(bob), 3000);
        assertEq(token.totalSupply(), 3000);

        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(user, address(vault), false);

        deal(address(underlying), address(size), 1000);
        vm.prank(address(size));
        underlying.approve(address(token), 1000);

        vm.prank(address(size));
        token.deposit(user, 1000);
        assertEq(token.balanceOf(user), 1000);
        assertEq(token.totalSupply(), 4000);

        vm.prank(owner);
        token.removeVault(address(vault));

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(EnumerableMap.EnumerableMapNonexistentKey.selector, address(vault)));
        token.withdraw(user, user, 500);

        vm.expectRevert(abi.encodeWithSelector(EnumerableMap.EnumerableMapNonexistentKey.selector, address(vault)));
        token.balanceOf(user);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(EnumerableMap.EnumerableMapNonexistentKey.selector, address(vault)));
        token.setVault(user, DEFAULT_VAULT, false);

        assertEq(token.totalSupply(), 3000);
        assertEq(token.balanceOf(bob), 3000);
    }

    function test_NonTransferrableRebasingTokenVault_transferFrom_aave_to_aave() public {
        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableRebasingTokenVault_transferFrom_aave_to_vault() public {
        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(owner, address(vault), false);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableRebasingTokenVault_transferFrom_vault_to_aave() public {
        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(user, address(vault), false);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableRebasingTokenVault_transferFrom_vault_to_vault() public {
        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(user, address(vault), false);
        vm.prank(address(size));
        token.setVault(owner, address(vault), false);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IAdapter.InsufficientAssets.selector, address(vault), 500, 900));
        token.transferFrom(user, owner, 900);
    }

    function test_NonTransferrableRebasingTokenVault_totalSupply_2() public {
        vm.prank(owner);
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        vm.prank(address(size));
        token.setVault(bob, address(vault), false);

        deal(address(underlying), address(size), 1_000e6);
        vm.prank(address(size));
        underlying.approve(address(token), 1_000e6);

        vm.prank(address(size));
        token.deposit(bob, 1_000e6);
        assertEq(token.balanceOf(bob), 1_000e6);
        assertEq(token.totalSupply(), 1_000e6);

        deal(address(underlying), address(size), 300e6);
        vm.prank(address(size));
        underlying.approve(address(token), 300e6);

        vm.prank(address(size));
        token.deposit(candy, 300e6);
        assertEq(token.balanceOf(bob), 1_000e6);
        assertEq(token.balanceOf(candy), 300e6);
        assertEq(token.totalSupply(), 1_300e6);
        assertEq(underlying.balanceOf(address(vault)), 1_000e6 + INITIAL_VAULT_ASSETS);
        assertEq(underlying.balanceOf(address(aToken)), 300e6);

        deal(address(underlying), address(liquidator), 1_000e6 + INITIAL_VAULT_ASSETS);
        vm.prank(liquidator);
        underlying.transfer(address(vault), 1_000e6 + INITIAL_VAULT_ASSETS);

        assertEqApprox(token.balanceOf(bob), 2_000e6, 1);
        assertEq(token.balanceOf(candy), 300e6);
        assertEq(underlying.balanceOf(address(vault)), (1_000e6 + INITIAL_VAULT_ASSETS) * 2);
        assertEq(underlying.balanceOf(address(aToken)), 300e6);
        assertEqApprox(token.totalSupply(), 2_300e6, 1);

        _deposit(james, address(underlying), 400e6);

        assertEqApprox(token.balanceOf(bob), 2_000e6, 1);
        assertEq(token.balanceOf(candy), 300e6);
        assertEq(token.balanceOf(james), 400e6);
        assertEq(underlying.balanceOf(address(vault)), (1_000e6 + INITIAL_VAULT_ASSETS) * 2);
        assertEq(underlying.balanceOf(address(aToken)), 700e6);
        assertEqApprox(token.totalSupply(), 2_700e6, 1);

        deal(address(underlying), address(liquidator), 350e6);
        vm.prank(liquidator);
        underlying.transfer(address(aToken), 350e6);
        _setLiquidityIndex(1.5e27);

        assertEqApprox(token.balanceOf(bob), 2_000e6, 1);
        assertEq(token.balanceOf(candy), 450e6);
        assertEq(token.balanceOf(james), 600e6);
        assertEq(underlying.balanceOf(address(vault)), (1_000e6 + INITIAL_VAULT_ASSETS) * 2);
        assertEq(underlying.balanceOf(address(aToken)), 1050e6);
        assertEqApprox(token.totalSupply(), 3_050e6, 1);
    }

    function test_NonTransferrableRebasingTokenVault_onlyAdapter() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED.selector, alice));
        vm.prank(alice);
        token.setSharesOf(alice, 1_000e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED.selector, alice));
        vm.prank(alice);
        token.requestApprove(address(vault), type(uint256).max);
    }

    function test_NonTransferrableRebasingTokenVault_getWhitelistedVaults() public view {
        (address[] memory vaults, address[] memory adapters, bytes32[] memory adapterTypes) =
            token.getWhitelistedVaults();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], DEFAULT_VAULT);
        assertEq(adapters.length, 1);
        assertEq(adapterTypes.length, 1);
        assertEq(adapterTypes[0], bytes32("AaveAdapter"));
    }

    function test_NonTransferrableRebasingTokenVault_balanceOf_totalSupply_directly_through_adapter() public {
        vm.prank(address(owner));
        token.setVaultAdapter(address(vault), "ERC4626Adapter");

        _deposit(alice, address(underlying), 40e6);

        IAdapter adapterVault = token.getWhitelistedVaultAdapter(address(vault));
        IAdapter adapterAave = token.getWhitelistedVaultAdapter(DEFAULT_VAULT);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vault)));
        adapterVault.balanceOf(address(vault), alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, DEFAULT_VAULT));
        adapterVault.balanceOf(DEFAULT_VAULT, alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vault)));
        adapterAave.balanceOf(address(vault), alice);

        assertEq(adapterAave.balanceOf(DEFAULT_VAULT, alice), 40e6);

        assertEq(adapterVault.totalSupply(address(vault)), 0);
        assertEq(adapterAave.totalSupply(DEFAULT_VAULT), 40e6);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, DEFAULT_VAULT));
        adapterVault.totalSupply(DEFAULT_VAULT);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vault)));
        adapterAave.totalSupply(address(vault));

        vm.prank(address(size));
        token.setVault(bob, address(vault), false);

        _deposit(bob, address(underlying), 30e6);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, DEFAULT_VAULT));
        adapterVault.balanceOf(DEFAULT_VAULT, bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, DEFAULT_VAULT));
        adapterAave.balanceOf(DEFAULT_VAULT, bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vault)));
        adapterAave.balanceOf(address(vault), bob);

        assertEq(adapterVault.balanceOf(address(vault), bob), 30e6);

        assertEq(adapterVault.totalSupply(address(vault)), 30e6);
        assertEq(adapterAave.totalSupply(DEFAULT_VAULT), 40e6);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, DEFAULT_VAULT));
        adapterVault.totalSupply(DEFAULT_VAULT);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vault)));
        adapterAave.totalSupply(address(vault));
    }

    function test_NonTransferrableRebasingTokenVault_reinitialize_reverts_unauthorized() public {
        // Should revert when called by non-owner
        vm.prank(alice);
        vm.expectRevert();
        token.reinitialize("name", "symbol", AaveAdapter(address(0)), ERC4626Adapter(address(0)));

        vm.prank(bob);
        vm.expectRevert();
        token.reinitialize("name", "symbol", AaveAdapter(address(0)), ERC4626Adapter(address(0)));

        vm.prank(candy);
        vm.expectRevert();
        token.reinitialize("name", "symbol", AaveAdapter(address(0)), ERC4626Adapter(address(0)));
    }
}
