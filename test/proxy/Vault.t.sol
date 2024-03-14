// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Vault} from "@src/proxy/Vault.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";
import {Test} from "forge-std/Test.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract VaultTest is Test {
    WETH public weth;
    USDC public usdc;
    Vault public vault;
    address owner = address(0x2);

    function setUp() public {
        usdc = new USDC(address(this));
        usdc.mint(address(this), 123e6);

        weth = new WETH();
    }

    function test_Vault_is_initializeable() public {
        vault = new Vault();
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(address(this));
        assertEq(vault.owner(), address(0));

        Vault proxy = Vault(payable(Clones.clone(address(vault))));
        proxy.initialize(address(this));
        assertEq(proxy.owner(), address(this));
    }

    function test_Vault_proxy() public {
        vault = new Vault();
        Vault proxy = Vault(payable(Clones.clone(address(vault))));
        proxy.initialize(address(this));

        bytes memory ans;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        ans = proxy.proxy(address(0), abi.encodeCall(ERC20.balanceOf, address(this)));

        ans = proxy.proxy(address(usdc), abi.encodeCall(ERC20.balanceOf, address(this)));

        assertEq(abi.decode(ans, (uint256)), 123e6);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(proxy)));
        ans = proxy.proxy(address(usdc), abi.encodeCall(USDC.mint, (address(this), 42e6)));
    }

    function test_Vault_proxy_value() public {
        vault = new Vault();
        Vault proxy = Vault(payable(Clones.clone(address(vault))));
        proxy.initialize(address(this));
        (bool success,) = payable(address(proxy)).call{value: 1 ether}("");
        assertTrue(success);

        bytes memory ans;

        vm.expectRevert(abi.encodeWithSelector(Address.FailedInnerCall.selector));
        ans = proxy.proxy(address(usdc), abi.encodeCall(USDC.mint, (address(this), 42e6)), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        ans = proxy.proxy(address(0), abi.encodeCall(WETH.deposit, ()), 1 ether);

        assertEq(address(proxy).balance, 1 ether);
        assertEq(weth.balanceOf(address(proxy)), 0);

        ans = proxy.proxy(address(weth), abi.encodeCall(WETH.deposit, ()), 1 ether);

        assertEq(address(proxy).balance, 0);
        assertEq(weth.balanceOf(address(proxy)), 1 ether);
    }

    function test_Vault_proxy_n() public {
        vault = new Vault();
        Vault proxy = Vault(payable(Clones.clone(address(vault))));
        proxy.initialize(address(this));

        address[] memory targets = new address[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = address(usdc);
        datas[0] = abi.encodeCall(ERC20.balanceOf, address(this));

        bytes[] memory ans;

        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        ans = proxy.proxy(targets, new bytes[](1));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        ans = proxy.proxy(targets, datas);

        targets[1] = address(usdc);
        datas[1] = abi.encodeCall(USDC.mint, (address(this), 42e6));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(proxy)));
        ans = proxy.proxy(targets, datas);
    }
}
