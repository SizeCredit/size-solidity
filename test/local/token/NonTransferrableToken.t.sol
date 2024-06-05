// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";
import {Test} from "forge-std/Test.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract NonTransferrableTokenTest is Test {
    NonTransferrableToken public token;
    address owner = address(0x2);

    function setUp() public {
        token = new NonTransferrableToken(owner, "Test", "TEST", 18);

        vm.label(owner, "owner");
    }

    function test_NonTransferrableToken_construction() public {
        assertEq(token.name(), "Test");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableToken_only_owner_can_mint() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.mint(address(this), 100);

        vm.prank(owner);
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
    }

    function test_NonTransferrableToken_only_owner_can_burn() public {
        vm.prank(owner);
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.burn(address(this), 100);

        vm.prank(owner);
        token.burn(address(this), 100);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableToken_only_owner_can_transfer() public {
        vm.prank(owner);
        token.mint(address(this), 13);
        vm.prank(owner);
        token.mint(owner, 42);

        assertEq(token.balanceOf(address(this)), 13);
        assertEq(token.balanceOf(owner), 42);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.transfer(address(this), 42);
        assertEq(token.balanceOf(address(this)), 13);
        assertEq(token.balanceOf(owner), 42);

        vm.prank(owner);
        token.transfer(address(this), 42);
        assertEq(token.balanceOf(address(this)), 55);
        assertEq(token.balanceOf(owner), 0);
    }

    function test_NonTransferrableToken_only_owner_can_transferFrom() public {
        vm.prank(owner);
        token.mint(address(this), 13);
        vm.prank(owner);
        token.mint(owner, 42);

        assertEq(token.balanceOf(address(this)), 13);
        assertEq(token.balanceOf(owner), 42);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.transferFrom(address(this), owner, 13);
        assertEq(token.balanceOf(address(this)), 13);
        assertEq(token.balanceOf(owner), 42);

        vm.prank(owner);
        token.transferFrom(address(this), owner, 13);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(owner), 55);
    }

    function test_NonTransferrableToken_only_owner_has_allowance() public {
        assertEq(token.allowance(address(this), owner), type(uint256).max);
        assertEq(token.allowance(owner, address(this)), 0);
    }

    function test_NonTransferrableToken_approve_is_not_supported() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.approve(address(this), 100);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.approve(address(this), 100);
    }
}
