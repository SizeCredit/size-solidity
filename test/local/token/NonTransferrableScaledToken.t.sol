// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {NonTransferrableScaledToken} from "@src/token/NonTransferrableScaledToken.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {Test} from "forge-std/Test.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract NonTransferrableScaledTokenTest is Test {
    NonTransferrableScaledToken public token;
    address owner = address(0x2);
    USDC public underlying;
    IPool public pool;

    function setUp() public {
        underlying = new USDC(address(this));
        pool = IPool(address(new PoolMock()));
        PoolMock(address(pool)).setLiquidityIndex(address(underlying), WadRayMath.RAY);
        token = new NonTransferrableScaledToken(pool, IERC20Metadata(underlying), owner, "Test", "TEST", 18);
    }

    function test_NonTransferrableScaledToken_construction() public {
        assertEq(token.name(), "Test");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableScaledToken_mint_reverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.mint(address(this), 100);
    }

    function test_NonTransferrableScaledToken_burn_reverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.burn(address(this), 100);
    }

    function test_NonTransferrableScaledToken_transfer() public {
        vm.prank(owner);
        token.mintScaled(owner, 100);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(owner), 100);
        vm.prank(owner);
        token.transfer(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
        assertEq(token.balanceOf(owner), 0);
    }
}
