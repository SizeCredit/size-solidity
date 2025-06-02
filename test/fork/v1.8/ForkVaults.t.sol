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

contract ForkVaultsTest is ForkTest, Networks {
    IERC4626 public eUSDC22 = IERC4626(0xe0a80d35bB6618CBA260120b279d357978c42BCE);
    IERC4626Morpho public morphoUSUALUSDCplus = IERC4626Morpho(0xd63070114470f685b75B74D60EEc7c1113d33a3D);
    IERC20Metadata public liquidUSD = IERC20Metadata(0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C);

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
            script.getTargetsAndDatas(sizeFactory, new address[](0), address(0), address(0), new ISize[](0));

        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(owner);
            (bool success,) = targets[i].call(datas[i]);
            assertTrue(success);
        }
    }

    function testFork_ForkVaults_aave() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);

        uint256 usdcBalanceBefore = usdc.balanceOf(address(aToken));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(aToken));
        assertEq(usdcBalanceAfter, usdcBalanceBefore + 100e6);
        assertEq(borrowTokenVault.balanceOf(alice), 100e6);

        _withdraw(alice, usdc, type(uint256).max);

        assertEq(usdc.balanceOf(alice), 100e6);
    }

    function testForkFuzz_ForkVaults_aave_deposit_withdraw(uint256 amount) public {
        amount = bound(amount, 1e6, 100e6);
        _deposit(alice, usdc, 2 * amount);
        _withdraw(alice, usdc, amount);
    }

    function testFork_ForkVaults_aave_deposit_withdraw_concrete() public {
        testForkFuzz_ForkVaults_aave_deposit_withdraw(978402975432085823771835641085079416658343680694610975968609);
    }

    function testFork_ForkVaults_eUSDC22() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 usdcBalanceBefore = usdc.balanceOf(address(eUSDC22));

        vm.prank(owner);
        borrowTokenVault.setVaultAdapter(address(eUSDC22), "ERC4626Adapter");

        _setUserConfiguration(alice, address(eUSDC22), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(eUSDC22));
        assertEq(usdcBalanceAfter, usdcBalanceBefore + 100e6);
        assertEq(borrowTokenVault.balanceOf(alice), 100e6 - 1);

        _withdraw(alice, usdc, type(uint256).max);

        assertEq(usdc.balanceOf(alice), 100e6 - 1);
    }

    function testFork_ForkVaults_morphoUSUALUSDCplus() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 usdcBalanceBefore = usdc.balanceOf(morphoUSUALUSDCplus.MORPHO());
        console.log("usdcBalanceBefore", usdcBalanceBefore);
        vm.prank(owner);
        borrowTokenVault.setVaultAdapter(address(morphoUSUALUSDCplus), "ERC4626Adapter");

        _setUserConfiguration(alice, address(morphoUSUALUSDCplus), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(morphoUSUALUSDCplus.MORPHO());
        console.log("usdcBalanceAfter ", usdcBalanceAfter);
        assertEq(usdcBalanceAfter, usdcBalanceBefore + 100e6);
        assertEq(borrowTokenVault.balanceOf(alice), 100e6 - 1);

        _withdraw(alice, usdc, type(uint256).max);

        assertEq(usdc.balanceOf(alice), 100e6 - 1);
    }

    function testFork_ForkVaults_liquidUSD() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 usdcBalanceBefore = usdc.balanceOf(address(liquidUSD));

        vm.prank(owner);
        vm.expectRevert();
        borrowTokenVault.setVaultAdapter(address(liquidUSD), "ERC4626Adapter");

        _setUserConfiguration(alice, address(liquidUSD), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(liquidUSD));

        assertEq(usdcBalanceAfter, usdcBalanceBefore);
    }
}
