// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Contract, Networks} from "@script/Networks.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

contract ForkVaultsTest is ForkTest, Networks {
    IERC4626 public eUSDC22 = IERC4626(0xe0a80d35bB6618CBA260120b279d357978c42BCE);
    IERC4626 public morphoUSUALUSDCplus = IERC4626(0xd63070114470f685b75B74D60EEc7c1113d33a3D);
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

        _labels();
    }

    function testFork_ForkVaults_eUSDC22() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 usdcBalanceBefore = usdc.balanceOf(address(eUSDC22));

        vm.prank(owner);
        borrowTokenVault.setVaultWhitelisted(address(eUSDC22), true);

        _setUserConfiguration(alice, address(eUSDC22), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(eUSDC22));
        assertEq(usdcBalanceAfter, usdcBalanceBefore + 100e6);
        assertEq(borrowTokenVault.balanceOf(alice), 100e6);
    }

    function testFork_ForkVaults_morphoUSUALUSDCplus() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 usdcBalanceBefore = usdc.balanceOf(address(morphoUSUALUSDCplus));

        vm.prank(owner);
        borrowTokenVault.setVaultWhitelisted(address(morphoUSUALUSDCplus), true);

        _setUserConfiguration(alice, address(morphoUSUALUSDCplus), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(morphoUSUALUSDCplus));
        assertEq(usdcBalanceAfter, usdcBalanceBefore + 100e6);
        assertEq(borrowTokenVault.balanceOf(alice), 100e6);
    }

    function testFork_ForkVaults_liquidUSD() public {
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 usdcBalanceBefore = usdc.balanceOf(address(liquidUSD));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(liquidUSD)));
        borrowTokenVault.setVaultWhitelisted(address(liquidUSD), true);

        _setUserConfiguration(alice, address(liquidUSD), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        uint256 usdcBalanceAfter = usdc.balanceOf(address(liquidUSD));

        assertEq(usdcBalanceAfter, usdcBalanceBefore);
    }
}
