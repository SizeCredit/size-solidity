// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

contract UpdateConfigValidationTest is BaseTest {
    function test_UpdateConfig_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_KEY.selector, "invalid"));
        size.updateConfig(UpdateConfigParams({key: "invalid", value: 1e18}));

        uint256 crLiquidation = size.riskConfig().crLiquidation;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_COLLATERAL_RATIO.selector, crLiquidation + 1));
        size.updateConfig(UpdateConfigParams({key: "crLiquidation", value: crLiquidation + 1}));

        uint256 maxTenor = 200 * 365 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.VALUE_GREATER_THAN_MAX.selector, maxTenor + 1, maxTenor));
        size.updateConfig(UpdateConfigParams({key: "minTenor", value: maxTenor + 1}));

        vm.expectRevert(abi.encodeWithSelector(Errors.VALUE_GREATER_THAN_MAX.selector, maxTenor + 1, maxTenor));
        size.updateConfig(UpdateConfigParams({key: "maxTenor", value: maxTenor + 1}));

        uint256 maxSwapFeeAPR = 0.2e18;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.VALUE_GREATER_THAN_MAX.selector, maxSwapFeeAPR + 1, maxSwapFeeAPR)
        );
        size.updateConfig(UpdateConfigParams({key: "swapFeeAPR", value: maxSwapFeeAPR + 1}));
    }

    function test_UpdateConfig_updateConfig_cannot_update_data() public {
        address variablePool = address(size.data().variablePool);
        address newVariablePool = makeAddr("newVariablePool");
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_KEY.selector, "variablePool"));
        size.updateConfig(UpdateConfigParams({key: "variablePool", value: uint256(uint160(newVariablePool))}));
        assertEq(address(size.data().variablePool), variablePool);
    }
}
