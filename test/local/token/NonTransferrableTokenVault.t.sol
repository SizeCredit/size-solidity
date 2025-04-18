// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableTokenVault} from "@src/market/token/NonTransferrableTokenVault.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {USDC} from "@test/mocks/USDC.sol";

contract NonTransferrableTokenVaultTest is BaseTest {
    NonTransferrableTokenVault public token;
    address user = address(0x10000);
    address owner = address(0x20000);
    USDC public underlying;
    IPool public pool;

    function setUp() public override {
        setupLocal(owner, feeRecipient);

        underlying = USDC(address(size.data().underlyingBorrowToken));
        pool = size.data().variablePool;
        token = size.data().borrowTokenVault;

        _labels();
    }

    function test_NonTransferrableTokenVault_initialize() public view {
        assertEq(token.name(), "Size USD Coin Vault");
        assertEq(token.symbol(), "svUSDC");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(address(token.sizeFactory()), address(sizeFactory));
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_NonTransferrableTokenVault_validation() public {
        NonTransferrableTokenVault implementation = new NonTransferrableTokenVault();
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        token = NonTransferrableTokenVault(
            address(
                new ERC1967Proxy(
                    address(implementation),
                    abi.encodeCall(
                        NonTransferrableTokenVault.initialize,
                        (
                            ISizeFactory(address(0)),
                            IPool(address(0)),
                            IERC20Metadata(address(0)),
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

    function test_NonTransferrableTokenVault_upgrade() public {
        NonTransferrableTokenVault implementation = new NonTransferrableTokenVault();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        token.upgradeToAndCall(address(implementation), bytes(""));

        vm.prank(owner);
        token.upgradeToAndCall(address(implementation), bytes(""));
    }

    function test_NonTransferrableTokenVault_transferFrom() public {
        vm.prank(address(size));
        deal(address(token), user, 100);

        vm.expectRevert(abi.encodeWithSelector(Errors.UNAUTHORIZED.selector, owner));
        vm.prank(owner);
        token.transferFrom(user, address(this), 50);

        vm.prank(address(size));
        token.transferFrom(user, address(this), 50);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.transferFrom(address(0), address(this), 50);

        vm.prank(address(size));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(user, address(0), 50);
    }

    function test_NonTransferrableTokenVault_transfer() public {
        vm.prank(address(size));
        deal(address(token), address(size), 100);

        assertEq(token.balanceOf(address(size)), 100);
        assertEq(token.balanceOf(user), 0);

        vm.prank(address(size));
        token.transfer(user, 30);

        assertEq(token.balanceOf(user), 30);
        assertEq(token.balanceOf(address(size)), 70);
    }

    function test_NonTransferrableTokenVault_totalSupply() public {
        deal(address(underlying), address(size), 300);
        vm.prank(address(size));
        assertEq(token.totalSupply(), 300);
    }

    function test_NonTransferrableTokenVault_allowance() public view {
        assertEq(token.allowance(user, address(this)), 0);
        assertEq(token.allowance(user, owner), 0);
        assertEq(token.allowance(user, address(size)), type(uint256).max);
    }

    function test_NonTransferrableTokenVault_approveReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        token.approve(address(this), 100);
    }

    function test_NonTransferrableTokenVault_liquidityIndex() public view {
        uint256 liquidityIndex = token.liquidityIndex();
        assertEq(liquidityIndex, WadRayMath.RAY);
    }

    function test_NonTransferrableTokenVault_deposit() public {
        vm.prank(owner);
        deal(address(underlying), address(size), 1000);

        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, user, 1000);
        assertEq(token.balanceOf(user), 1000);
    }

    function test_NonTransferrableTokenVault_withdraw() public {
        vm.prank(owner);
        deal(address(underlying), address(size), 1000);

        vm.prank(address(size));
        underlying.approve(address(token), 1000);
        vm.prank(address(size));
        token.deposit(user, user, 1000);
        vm.prank(address(size));
        token.withdraw(user, user, 500);
        assertEq(token.balanceOf(user), 500);
    }
}
