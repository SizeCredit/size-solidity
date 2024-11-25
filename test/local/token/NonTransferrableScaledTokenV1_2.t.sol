// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {NonTransferrableScaledTokenV1_2} from "@src/token/deprecated/NonTransferrableScaledTokenV1_2.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {Test} from "forge-std/Test.sol";

contract NonTransferrableScaledTokenV1_2Test is Test {
    NonTransferrableScaledTokenV1_2 public token;
    address owner = address(0x2);
    USDC public underlying;
    IPool public pool;

    function setUp() public {
        underlying = new USDC(address(this));
        pool = IPool(address(new PoolMock()));
        PoolMock(address(pool)).setLiquidityIndex(address(underlying), WadRayMath.RAY);
        token = new NonTransferrableScaledTokenV1_2(pool, IERC20Metadata(underlying), owner, "Test", "TEST", 18);
    }

    function test_NonTransferrableScaledTokenV1_2_construction() public view {
        assertEq(token.name(), "Test");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableScaledTokenV1_2_transfer() public {
        vm.prank(owner);
        token.mintScaled(owner, 100);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(owner), 100);
        vm.prank(owner);
        token.transfer(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
        assertEq(token.balanceOf(owner), 0);
    }

    function test_NonTransferrableScaledTokenV1_2_mintScaled_burnScaled() public {
        vm.prank(owner);
        token.mintScaled(owner, 42);
        vm.prank(owner);
        token.burnScaled(owner, 42);
        assertEq(token.balanceOf(owner), 0);
    }
}
