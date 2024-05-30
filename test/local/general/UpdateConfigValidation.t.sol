// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {UpdateConfigParams} from "@src/core/libraries/general/actions/UpdateConfig.sol";

contract UpdateConfigValidationTest is BaseTest {
    function test_UpdateConfig_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_KEY.selector, "invalid"));
        size.updateConfig(UpdateConfigParams({key: "invalid", value: 1e18}));
    }

    function test_UpdateConfig_updateConfig_cannot_update_data() public {
        address variablePool = address(size.data().variablePool);
        address newVariablePool = makeAddr("newVariablePool");
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_KEY.selector, "variablePool"));
        size.updateConfig(UpdateConfigParams({key: "variablePool", value: uint256(uint160(newVariablePool))}));
        assertEq(address(size.data().variablePool), variablePool);
    }
}
