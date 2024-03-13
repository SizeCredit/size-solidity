// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

import {Size} from "@src/Size.sol";

contract UpdateConfigTest is BaseTest {
    function test_UpdateConfig_updateConfig_reverts_if_not_owner() public {
        vm.startPrank(alice);

        assertTrue(size.riskConfig().minimumCreditBorrowAToken != 1e6);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
        size.updateConfig(UpdateConfigParams({key: "minimumCreditBorrowAToken", value: 1e6}));

        assertTrue(size.riskConfig().minimumCreditBorrowAToken != 1e6);
    }

    function test_UpdateConfig_updateConfig_updates_params() public {
        assertTrue(size.riskConfig().minimumCreditBorrowAToken != 1e6);

        size.updateConfig(UpdateConfigParams({key: "minimumCreditBorrowAToken", value: 1e6}));

        assertTrue(size.riskConfig().minimumCreditBorrowAToken == 1e6);
    }
}
