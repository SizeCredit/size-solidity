// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {CollectionsManager} from "@src/collections/CollectionsManager.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract CollectionsManagerAdminActionsTest is BaseTest {
    function test_CollectionsManagerAdminActions_only_admin_can_upgrade() public {
        CollectionsManager v2 = new CollectionsManager();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
        collectionsManager.upgradeToAndCall(address(v2), "");

        collectionsManager.upgradeToAndCall(address(v2), "");
    }
}
