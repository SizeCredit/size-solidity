// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract PauseTest is BaseTest {
    function test_Pause_pause_cannot_deposit() public {
        _mint(address(weth), alice, 2e18);

        _deposit(alice, weth, 1e18);

        size.pause();
        vm.expectRevert(abi.encodePacked(Pausable.EnforcedPause.selector));
        size.deposit(DepositParams({token: address(weth), amount: 1e18, to: alice, variable: false}));
    }

    function test_Pause_pause_can_updateConfig() public {
        assertGt(size.config().repayFeeAPR, 0);
        size.pause();
        size.updateConfig(UpdateConfigParams({key: "repayFeeAPR", value: 0}));
        assertEq(size.config().repayFeeAPR, 0);
    }
}
