// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Ownable2StepTest is BaseTest {
    function test_Ownable2Step_has_owner() public {
        assertEq(size.owner(), address(this));
    }

    function test_Ownable2Step_transferOwnership_does_not_change_owner() public {
        size.transferOwnership(address(0x1));
        assertEq(size.owner(), address(this));
    }

    function test_Ownable2Step_transferOwnership_changes_owner_acceptOwnership() public {
        size.transferOwnership(address(0x1));
        assertEq(size.owner(), address(this));
        vm.prank(address(0x1));
        size.acceptOwnership();
        assertEq(size.owner(), address(0x1));
    }

    function test_Ownable2Step_transferOwnership_reverts_if_not_owner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        size.transferOwnership(alice);
    }
}
