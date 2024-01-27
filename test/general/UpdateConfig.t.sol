// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

import {Size} from "@src/Size.sol";

contract UpdateConfigTest is BaseTest {
    function test_UpdateConfig_updateConfig_reverts_if_not_owner() public {
        vm.startPrank(alice);

        assertTrue(size.f().minimumCreditBorrowAsset != 1e6);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        size.updateConfig(UpdateConfigParams({key: "minimumCreditBorrowAsset", value: 1e6}));

        assertTrue(size.f().minimumCreditBorrowAsset != 1e6);
    }

    function test_UpdateConfig_updateConfig_updates_params() public {
        assertTrue(size.f().minimumCreditBorrowAsset != 1e6);

        size.updateConfig(UpdateConfigParams({key: "minimumCreditBorrowAsset", value: 1e6}));

        assertTrue(size.f().minimumCreditBorrowAsset == 1e6);
    }
}
