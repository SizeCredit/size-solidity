// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Errors} from "@src/libraries/Errors.sol";
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

    function test_UpdateConfig_updateConfig_cannot_maliciously_liquidate_all_positions() public {
        size.updateConfig(UpdateConfigParams({key: "crOpening", value: 10.0e18}));
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, 9.99e18));
        size.updateConfig(UpdateConfigParams({key: "crLiquidation", value: 9.99e18}));
    }
}
