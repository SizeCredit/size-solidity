// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
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
import {NonTransferrableTokenVault} from "@src/market/token/NonTransferrableTokenVault.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

contract NonTransferrableTokenVaultTest is BaseTest {
    NonTransferrableTokenVault public token;
    address user = address(0x10000);
    address owner = address(0x20000);
    USDC public underlying;
    IPool public pool;

    function setUp() public override {
        setupLocal(owner, feeRecipient);

        underlying = USDC(address(size.data().underlyingBorrowToken));
        pool = size.data().variablePool;
        token = size.data().borrowTokenVault;

        _labels();

        // first deposit
        deal(address(underlying), address(alice), 1e18);
        vm.prank(alice);
        underlying.approve(address(vault), 1e18);
        vm.prank(alice);
        vault.deposit(1e18, alice);
    }

    function test_NonTransferrableTokenVault_initialize() public view {
        assertEq(token.name(), "Size USD Coin Vault");
        assertEq(token.symbol(), "svUSDC");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(address(token.sizeFactory()), address(sizeFactory));
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableTokenVault_validation() public {
        NonTransferrableTokenVault implementation = new NonTransferrableTokenVault();
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        token = NonTransferrableTokenVault(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(
                        NonTransferrableTokenVault.initialize,
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

    function test_NonTransferrableTokenVault_upgrade() public {
        NonTransferrableTokenVault implementation = new NonTransferrableTokenVault();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.upgradeToAndCall(address(implementation), bytes(""));

        vm.prank(owner);
        token.upgradeToAndCall(address(implementation), bytes(""));
    }

    function test_NonTransferrableTokenVault_transferFrom() public {
        vm.prank(address(size));
        deal(address(token), user, 100);

        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED.selector, owner));
        vm.prank(owner);
        token.transferFrom(user, address(this), 50);

        vm.prank(address(size));
        token.transferFrom(user, address(this), 50);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.transferFrom(address(0), address(this), 50);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(user, address(0), 50);
    }

    function test_NonTransferrableTokenVault_transfer() public {
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

    function test_NonTransferrableTokenVault_totalSupply_1() public {
        deal(address(underlying), alice, 300);
        _deposit(alice, address(underlying), 300);
        assertEq(token.totalSupply(), 300);
    }

    function test_NonTransferrableTokenVault_allowance() public view {
        assertEq(token.allowance(user, address(this)), 0);
        assertEq(token.allowance(user, owner), 0);
        assertEq(token.allowance(user, address(size)), type(uint256).max);
    }

    function test_NonTransferrableTokenVault_approveReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.approve(address(this), 100);
    }

    function test_NonTransferrableTokenVault_deposit() public {
        vm.prank(owner);
        deal(address(underlying), address(size), 1000);

        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, user, 1000);
        assertEq(token.balanceOf(user), 1000);
    }

    function test_NonTransferrableTokenVault_withdraw() public {
        vm.prank(owner);
        deal(address(underlying), address(size), 1000);

        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, user, 1000);
        vm.prank(address(size));
        token.withdraw(user, user, 500);
        assertEq(token.balanceOf(user), 500);
    }

    function test_NonTransferrableTokenVault_setUserVaultWhitelistEnabled() public {
        vm.prank(owner);
        token.setUserVaultWhitelistEnabled(false);
        assertTrue(!token.isUserVaultWhitelistEnabled());

        vm.prank(owner);
        token.setUserVaultWhitelisted(vault, true);
        assertTrue(token.isUserVaultWhitelisted(vault));
    }

    function test_NonTransferrableTokenVault_setUserVault() public {
        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(Errors.USER_VAULT_NOT_WHITELISTED.selector, address(vault)));
        token.setUserVault(alice, vault);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        token.setUserVault(address(0), vault);

        vm.prank(owner);
        token.setUserVaultWhitelisted(vault, true);

        vm.prank(address(size));
        token.setUserVault(alice, vault);
        assertEq(address(token.userVault(alice)), address(vault));
    }

    function test_NonTransferrableTokenVault_userVault_deposit_withdraw_path() public {
        vm.prank(owner);
        token.setUserVaultWhitelisted(vault, true);

        vm.prank(address(size));
        token.setUserVault(user, vault);

        deal(address(underlying), address(size), 1000);
        vm.prank(address(size));
        underlying.approve(address(token), 1000);

        vm.prank(address(size));
        token.deposit(user, user, 1000);
        assertEq(token.balanceOf(user), 1000);

        vm.prank(address(size));
        token.withdraw(user, user, 500);
        assertEq(token.balanceOf(user), 500);
    }

    function test_NonTransferrableTokenVault_pps() public {
        assertEq(token.pps(IERC4626(address(0))), token.liquidityIndex());

        vm.prank(owner);
        token.setUserVaultWhitelistEnabled(false);

        vm.prank(address(size));
        token.setUserVault(user, vault);

        deal(address(underlying), address(size), 1000);
        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, user, 1000);

        assertEq(token.pps(vault), 1e27);

        deal(address(underlying), address(vault), 1500);
        assertEq(token.pps(vault), uint256(1500 * 1e27) / (1e18 + 1000));
    }

    function test_NonTransferrableTokenVault_transferFrom_aave_to_aave() public {
        vm.prank(owner);
        token.setUserVaultWhitelistEnabled(false);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableTokenVault_transferFrom_aave_to_vault() public {
        vm.prank(owner);
        token.setUserVaultWhitelistEnabled(false);

        vm.prank(address(size));
        token.setUserVault(owner, vault);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableTokenVault_transferFrom_vault_to_aave() public {
        vm.prank(owner);
        token.setUserVaultWhitelistEnabled(false);

        vm.prank(address(size));
        token.setUserVault(user, vault);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableTokenVault_transferFrom_vault_to_vault() public {
        vm.prank(owner);
        token.setUserVaultWhitelistEnabled(false);

        vm.prank(address(size));
        token.setUserVault(user, vault);
        vm.prank(address(size));
        token.setUserVault(owner, vault);

        deal(address(underlying), address(size), 500);
        vm.prank(address(size));
        underlying.approve(address(token), 500);

        vm.prank(address(size));
        token.deposit(user, user, 500);

        vm.prank(address(size));
        token.transferFrom(user, owner, 100);
        assertEq(token.balanceOf(user), 400);
        assertEq(token.balanceOf(owner), 100);
    }

    function test_NonTransferrableTokenVault_totalSupply_2() public {
        vm.prank(owner);
        token.setUserVaultWhitelisted(vault, true);

        vm.prank(address(size));
        token.setUserVault(user, vault);

        deal(address(underlying), address(size), 1_000e6);
        vm.prank(address(size));
        underlying.approve(address(token), 1_000e6);

        vm.prank(address(size));
        token.deposit(user, user, 1_000e6);
        assertEq(token.balanceOf(user), 1_000e6);

        deal(address(underlying), address(size), 300e6);
        vm.prank(address(size));
        underlying.approve(address(token), 300e6);

        vm.prank(address(size));
        token.deposit(bob, bob, 300e6);
        assertEq(token.balanceOf(bob), 300e6);

        deal(address(underlying), address(vault), 1_200e6);

        assertEq(token.totalSupply(), 1_300e6);
    }
}
