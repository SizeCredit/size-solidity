// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Networks} from "@script/Networks.sol";
import {IMultiSendCallOnly} from "@script/interfaces/IMultiSendCallOnly.sol";

import {ProposeSafeTxV1_7ReinitializeScript} from "@script/ProposeSafeTxV1_7Reinitialize.s.sol";

import {ISafe} from "@script/interfaces/ISafe.sol";
import {VERSION} from "@src/market/interfaces/ISize.sol";
import {SafeUtils} from "@test/SafeUtils.sol";

import {ActionsBitmap} from "@src/factory/libraries/Authorization.sol";

contract ForkReinitializeV1_7Test is ForkTest, ProposeSafeTxV1_7ReinitializeScript, SafeUtils {
    struct Vars {
        ISizeFactory sizeFactory;
        IMultiSendCallOnly multiSendCallOnly;
        address owner;
    }

    function setUp() public override {
        super.setUp();
    }

    function _getV1_7ReinitializeAddresses(string memory network, uint256 blockNumber)
        private
        returns (Vars memory vars)
    {
        vm.createSelectFork(Strings.equal(network, "base-production") ? "base_archive" : network, blockNumber);
        vars.sizeFactory = importSizeFactory(string.concat(network, "-size-factory"));
        vars.multiSendCallOnly = multiSendCallOnly(network);
        vars.owner = OwnableUpgradeable(address(vars.sizeFactory)).owner();

        sizeV1_7 = new Size();
        sizeFactoryV1_7 = new SizeFactory();

        vm.label(address(vars.sizeFactory), "SizeFactory");
        vm.label(address(vars.multiSendCallOnly), "MultiSendCallOnly");
        vm.label(vars.owner, "owner");
    }

    function _testFork_ForkReinitializeV1_7_reinitialize(string memory network, uint256 blockNumber) private {
        Vars memory vars = _getV1_7ReinitializeAddresses(network, blockNumber);

        (address to, bytes memory data) = getV1_7ReinitializeData(vars.sizeFactory, vars.multiSendCallOnly);

        // pre-checks
        ISize[] memory markets = vars.sizeFactory.getMarkets();
        address[] memory borrowATokenV1_5 = new address[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            ISize market = markets[i];
            borrowATokenV1_5[i] = address(market.data().borrowAToken);
            assertTrue(Strings.equal(market.version(), "v1.6.1"), "all markets should be in v1.6.1");
        }
        (bool success,) = address(vars.sizeFactory).call(
            abi.encodeWithSelector(ISizeFactoryV1_7.setAuthorization.selector, address(0x1000), 1)
        );
        assertTrue(!success, "should not be able to call setAuthorization on v1.6.1");
        (success,) =
            address(vars.sizeFactory).call(abi.encodeWithSelector(IAccessControl.hasRole.selector, vars.owner, 0x00));
        assertTrue(!success, "should not be able to call hasRole");
        assertTrue(OwnableUpgradeable(address(vars.sizeFactory)).owner() == address(vars.owner), "owner should be set");
        assertTrue(!Strings.equal(VERSION, "v1.6.1"), "VERSION should not be v1.6.1");

        console.log("to", to);
        console.logBytes(data);

        _simulateSafeMultiSendCallOnly(ISafe(vars.owner), to, data);

        // post-checks
        for (uint256 i = 0; i < markets.length; i++) {
            ISize market = markets[i];
            assertEq(address(market.data().borrowAToken), borrowATokenV1_5[i], "data() does not break");
            assertEq(address(market.sizeFactory()), address(vars.sizeFactory), "all markets should have `sizeFactory`");
            assertEq(market.version(), VERSION, "all markets should be in the new version");
        }
        (success,) = address(vars.sizeFactory).call(
            abi.encodeWithSelector(ISizeFactoryV1_7.setAuthorization.selector, address(0x1000), 1)
        );
        assertTrue(success, "should be able to call setAuthorization on v1.7");
        (success,) =
            address(vars.sizeFactory).call(abi.encodeWithSelector(IAccessControl.hasRole.selector, vars.owner, 0x00));
        assertTrue(success, "should be able to call hasRole");
        assertTrue(OwnableUpgradeable(address(vars.sizeFactory)).owner() == address(0), "owner should be set to zero");

        Size market0 = Size(address(vars.sizeFactory.getMarket(0)));
        f = InitializeFeeConfigParams({
            swapFeeAPR: market0.feeConfig().swapFeeAPR,
            fragmentationFee: market0.feeConfig().fragmentationFee,
            liquidationRewardPercent: market0.feeConfig().liquidationRewardPercent,
            overdueCollateralProtocolPercent: market0.feeConfig().overdueCollateralProtocolPercent,
            collateralProtocolPercent: market0.feeConfig().collateralProtocolPercent,
            feeRecipient: vars.owner
        });
        r = InitializeRiskConfigParams({
            crOpening: market0.riskConfig().crOpening,
            crLiquidation: market0.riskConfig().crLiquidation,
            minimumCreditBorrowAToken: market0.riskConfig().minimumCreditBorrowAToken,
            borrowATokenCap: market0.riskConfig().borrowATokenCap,
            minTenor: market0.riskConfig().minTenor,
            maxTenor: market0.riskConfig().maxTenor
        });
        o = InitializeOracleParams({
            priceFeed: address(market0.oracle().priceFeed),
            variablePoolBorrowRateStaleRateInterval: market0.oracle().variablePoolBorrowRateStaleRateInterval
        });
        d = InitializeDataParams({
            weth: address(market0.data().underlyingCollateralToken),
            underlyingCollateralToken: address(market0.data().underlyingCollateralToken),
            underlyingBorrowToken: address(market0.data().underlyingBorrowToken),
            variablePool: address(market0.data().variablePool),
            borrowATokenV1_5: address(market0.data().borrowAToken),
            sizeFactory: address(vars.sizeFactory)
        });
        vm.prank(vars.owner);
        vars.sizeFactory.createMarket(f, r, o, d);

        address _variablePool = address(market0.data().variablePool);
        address _underlyingBorrowToken = address(market0.data().underlyingBorrowToken);

        vm.prank(vars.owner);
        vars.sizeFactory.createBorrowATokenV1_5(IPool(_variablePool), IERC20Metadata(_underlyingBorrowToken));
    }

    function testFork_ForkReinitializeV1_7_reinitialize() public {
        // 2025-02-21T12:00Z
        _testFork_ForkReinitializeV1_7_reinitialize("mainnet", 21894565);
        _testFork_ForkReinitializeV1_7_reinitialize("base-production", 26674900);
    }
}
