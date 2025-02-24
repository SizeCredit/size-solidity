// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {PAUSER_ROLE} from "@src/factory/interfaces/ISizeFactory.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract SizeFactoryReinitializeV1_7Test is BaseTest {
    function test_SizeFactoryReinitializeV1_7_reinitialize_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        sizeFactory.reinitialize();
    }

    function test_SizeFactoryReinitializeV1_7_reinitialize_can_still_execute_actions() public {
        sizeFactory.reinitialize();
        sizeFactory.removeMarket(size);
    }

    function test_SizeFactoryReinitializeV1_7_reinitialize_can_still_execute_upgrade() public {
        SizeFactory upgrade = new SizeFactory();
        sizeFactory.reinitialize();
        UUPSUpgradeable(address(sizeFactory)).upgradeToAndCall(address(upgrade), "");
    }

    function test_SizeFactoryReinitializeV1_7_reinitialize_cannot_reinitialize_twice() public {
        assertEq(sizeFactory.owner(), address(this));
        sizeFactory.reinitialize();
        assertEq(sizeFactory.owner(), address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        sizeFactory.reinitialize();
    }

    function test_SizeFactoryReinitializeV1_7_reinitialize_sizeFactory_only_pauser_can_pause_market() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, PAUSER_ROLE)
        );
        vm.prank(alice);
        size.pause();

        AccessControl(address(sizeFactory)).grantRole(PAUSER_ROLE, alice);
        vm.prank(alice);
        size.pause();
    }
}
