// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {SizeFactory} from "@src/v1.5/SizeFactory.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {Test} from "forge-std/Test.sol";

contract NonTransferrableScaledTokenV1_5Test is Test {
    NonTransferrableScaledTokenV1_5 public token;
    SizeFactory public sizeFactory;
    address user = address(0x1);
    address owner = address(0x2);
    address size = address(0x3);
    USDC public underlying;
    IPool public pool;

    function setUp() public {
        underlying = new USDC(address(this));
        pool = IPool(address(new PoolMock()));
        PoolMock(address(pool)).setLiquidityIndex(address(underlying), WadRayMath.RAY);
        sizeFactory = SizeFactory(
            address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (owner))))
        );
        token = NonTransferrableScaledTokenV1_5(
            address(
                new ERC1967Proxy(
                    address(new NonTransferrableScaledTokenV1_5()),
                    abi.encodeCall(
                        NonTransferrableScaledTokenV1_5.initialize,
                        (
                            sizeFactory,
                            IPool(address(pool)),
                            IERC20Metadata(address(underlying)),
                            owner,
                            "Test",
                            "TEST",
                            18
                        )
                    )
                )
            )
        );
    }

    function test_NonTransferrableScaledTokenV1_5_construction() public view {
        assertEq(token.name(), "Test");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(address(token.sizeFactory()), address(sizeFactory));
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableScaledTokenV1_5_mintScaled() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        vm.prank(size);
        token.mintScaled(user, 100);
        assertEq(token.balanceOf(user), 100);
    }

    function test_NonTransferrableScaledTokenV1_5_burnScaled() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        vm.prank(size);
        token.mintScaled(user, 100);
        vm.prank(size);
        token.burnScaled(user, 100);
        assertEq(token.balanceOf(user), 0);
    }

    function test_NonTransferrableScaledTokenV1_5_transferFrom() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        vm.prank(size);
        token.mintScaled(user, 100);

        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED.selector, owner));
        vm.prank(owner);
        token.transferFrom(user, address(this), 50);

        vm.prank(size);
        token.transferFrom(user, address(this), 50);
    }

    function test_NonTransferrableScaledTokenV1_5_scaledBalanceOf() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        vm.prank(size);
        token.mintScaled(user, 200);
        assertEq(token.scaledBalanceOf(user), 200);
    }

    function test_NonTransferrableScaledTokenV1_5_totalSupply() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        vm.prank(size);
        token.mintScaled(user, 300);
        assertEq(token.totalSupply(), 300);
    }

    function test_NonTransferrableScaledTokenV1_5_allowance() public {
        assertEq(token.allowance(user, address(this)), 0);
        assertEq(token.allowance(user, owner), 0);
        assertEq(token.allowance(user, size), 0);

        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));
        assertEq(token.allowance(user, address(this)), 0);
        assertEq(token.allowance(user, owner), 0);
        assertEq(token.allowance(user, size), type(uint256).max);
    }

    function test_NonTransferrableScaledTokenV1_5_approveReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.approve(address(this), 100);
    }

    function test_NonTransferrableScaledTokenV1_5_liquidityIndex() public view {
        uint256 liquidityIndex = token.liquidityIndex();
        assertEq(liquidityIndex, WadRayMath.RAY);
    }

    function test_NonTransferrableScaledTokenV1_5_deposit() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        underlying.mint(size, 1000);
        vm.prank(size);
        underlying.approve(address(token), 1000);
        vm.prank(size);
        token.deposit(user, user, 1000);
        assertEq(token.balanceOf(user), 1000);
    }

    function test_NonTransferrableScaledTokenV1_5_withdraw() public {
        vm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        underlying.mint(size, 1000);
        vm.prank(size);
        underlying.approve(address(token), 1000);
        vm.prank(size);
        token.deposit(user, user, 1000);
        vm.prank(size);
        token.withdraw(user, user, 500);
        assertEq(token.balanceOf(user), 500);
    }
}
