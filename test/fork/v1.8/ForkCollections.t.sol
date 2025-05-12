// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Contract, Networks} from "@script/Networks.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";
import {console} from "forge-std/console.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626Morpho} from "@test/fork/v1.8/interfaces/IERC4626Morpho.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {ProposeSafeTxUpgradeToV1_8Script} from "@script/ProposeSafeTxUpgradeToV1_8.s.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {Adapter} from "@src/market/token/libraries/AdapterLibrary.sol";

contract ForkCollectionsTest is ForkTest, Networks {
    function setUp() public override(ForkTest) {
        vm.createSelectFork("mainnet");
        // 2025-04-28 14h30 UTC
        vm.rollFork(22368140);

        sizeFactory = importSizeFactory("mainnet-size-factory");
        size = SizeMock(address(sizeFactory.getMarket(0)));
        usdc = USDC(address(size.data().underlyingBorrowToken));
        weth = WETH(payable(address(size.data().underlyingCollateralToken)));
        variablePool = size.data().variablePool;
        owner = Networks.contracts[block.chainid][Contract.SIZE_GOVERNANCE];

        _upgradeToV1_8();

        _labels();
    }

    function _upgradeToV1_8() internal {
        ProposeSafeTxUpgradeToV1_8Script script = new ProposeSafeTxUpgradeToV1_8Script();

        (address[] memory targets, bytes[] memory datas) =
            script.getTargetsAndDatas(sizeFactory, new address[](0), address(0), new ISize[](0));

        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(owner);
            (bool success,) = targets[i].call(datas[i]);
            assertTrue(success);
        }
    }

    function testFork_ForkCollections_users_subscribing_to_existing_RP_now_have_1_collection() public {}

    function testFork_ForkCollections_market_orders_on_users_subscribing_to_existing_RP_now_fail_if_no_collection_is_passed(
    ) public {}
}
