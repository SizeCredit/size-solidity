// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ATokenVault} from "@src/token/ATokenVault.sol";
import {Test} from "forge-std/Test.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract ATokenVaultTest is Test {
    ERC20Mock token;
    ATokenVault vault;
    address owner = address(0x2);

    function setUp() public {
        token = new ERC20Mock();
        PoolMock variablePool = new PoolMock();
        variablePool.setLiquidityIndex(address(token), WadRayMath.RAY);
        vault = new ATokenVault(IPool(address(variablePool)), address(token), owner, "Vault", "VLT", token.decimals());
    }

    function test_ATokenVault_construction() public {
        assertEq(vault.name(), "Vault");
        assertEq(vault.symbol(), "VLT");
        assertEq(vault.decimals(), 18);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.owner(), owner);
        assertEq(vault.balanceOf(address(this)), 0);
    }

    function test_ATokenVault_only_owner_can_mint() public {
        token.mint(owner, 100);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.mint(address(this), 100);

        vm.startPrank(owner);
        token.approve(address(vault), 100);
        vault.mint(address(this), 100);
        vm.stopPrank();
        assertEq(vault.balanceOf(address(this)), 100);
    }

    function test_ATokenVault_only_owner_can_burn() public {
        token.mint(owner, 100);

        vm.startPrank(owner);
        token.approve(address(vault), 100);
        vault.mint(address(this), 100);
        vm.stopPrank();
        assertEq(vault.balanceOf(address(this)), 100);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.burn(address(this), 100);

        vm.prank(owner);
        vault.burn(address(this), 100);
        assertEq(vault.balanceOf(address(this)), 0);
    }

    function test_ATokenVault_only_owner_can_transfer() public {
        token.mint(owner, 42 + 13);

        vm.startPrank(owner);
        token.approve(address(vault), 42);
        vault.mint(owner, 42);
        vm.stopPrank();

        vm.startPrank(owner);
        token.approve(address(vault), 13);
        vault.mint(address(this), 13);
        vm.stopPrank();

        assertEq(vault.balanceOf(address(this)), 13);
        assertEq(vault.balanceOf(owner), 42);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.transfer(address(this), 42);
        assertEq(vault.balanceOf(address(this)), 13);
        assertEq(vault.balanceOf(owner), 42);

        vm.prank(owner);
        vault.transfer(address(this), 42);
        assertEq(vault.balanceOf(address(this)), 55);
        assertEq(vault.balanceOf(owner), 0);
    }

    function test_ATokenVault_only_owner_can_transferFrom() public {
        token.mint(owner, 42 + 13);

        vm.startPrank(owner);
        token.approve(address(vault), 42);
        vault.mint(owner, 42);
        vm.stopPrank();

        vm.startPrank(owner);
        token.approve(address(vault), 13);
        vault.mint(address(this), 13);
        vm.stopPrank();

        assertEq(vault.balanceOf(address(this)), 13);
        assertEq(vault.balanceOf(owner), 42);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.transferFrom(address(this), owner, 13);
        assertEq(vault.balanceOf(address(this)), 13);
        assertEq(vault.balanceOf(owner), 42);

        vm.prank(owner);
        vault.transferFrom(address(this), owner, 13);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.balanceOf(owner), 55);
    }

    function test_ATokenVault_only_owner_has_allowance() public {
        assertEq(vault.allowance(address(this), owner), type(uint256).max);
        assertEq(vault.allowance(owner, address(this)), 0);
    }

    function test_ATokenVault_approve_is_not_supported() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        vault.approve(address(this), 100);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        vault.approve(address(this), 100);
    }
}
