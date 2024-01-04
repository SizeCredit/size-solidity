// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Config} from "@src/SizeStorage.sol";
import {UpdateConfigParams} from "@src/libraries/actions/UpdateConfig.sol";

import {Size} from "@src/Size.sol";

contract UpdateConfigTest is BaseTest {
    function test_UpdateConfig_updateConfig_reverts_if_not_owner() public {
        vm.startPrank(alice);

        assertTrue(size.getConfig().minimumCredit != 1e18);

        Config memory config = size.getConfig();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        size.updateConfig(
            UpdateConfigParams({
                priceFeed: address(config.priceFeed),
                feeRecipient: config.feeRecipient,
                crOpening: config.crOpening,
                crLiquidation: config.crLiquidation,
                collateralPercentagePremiumToLiquidator: config.collateralPercentagePremiumToLiquidator,
                collateralPercentagePremiumToProtocol: config.collateralPercentagePremiumToProtocol,
                minimumCredit: 1e18
            })
        );

        assertTrue(size.getConfig().minimumCredit != 1e18);
    }

    function test_UpdateConfig_updateConfig_updates_params() public {
        assertTrue(size.getConfig().minimumCredit != 1e18);

        Config memory config = size.getConfig();
        size.updateConfig(
            UpdateConfigParams({
                priceFeed: address(config.priceFeed),
                feeRecipient: config.feeRecipient,
                crOpening: config.crOpening,
                crLiquidation: config.crLiquidation,
                collateralPercentagePremiumToLiquidator: config.collateralPercentagePremiumToLiquidator,
                collateralPercentagePremiumToProtocol: config.collateralPercentagePremiumToProtocol,
                minimumCredit: 1e18
            })
        );

        assertTrue(size.getConfig().minimumCredit == 1e18);
    }
}
