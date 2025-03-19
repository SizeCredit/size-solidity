// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract ReinitializeV1_7Test is BaseTest {
    bytes32 internal SIZE_FACTORY_SLOT = bytes32(uint256(28)); // calculated with the help of `cast storage`

    function _resetSizeFactory(address _size) internal {
        // reset sizeFactory to 0 address (only useful for local tests)
        vm.store(_size, SIZE_FACTORY_SLOT, bytes32(uint256(uint160(address(0)))));
    }

    function setUp() public override {
        super.setUp();
        _resetSizeFactory(address(size));
    }

    function test_ReinitializeV1_7_reinitialize_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
        size.reinitialize(sizeFactory);
    }

    function test_ReinitializeV1_7_reinitialize_not_null() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.reinitialize(ISizeFactory(address(0)));
    }

    function test_ReinitializeV1_7_reinitialize_must_be_market() public {
        Size size2 = new Size();
        SizeFactory sizeFactory2 = SizeFactory(
            address(
                new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (address(this))))
            )
        );
        sizeFactory2.setSizeImplementation(address(size2));
        d.sizeFactory = address(sizeFactory2);
        ISize size2proxy = sizeFactory2.createMarket(f, r, o, d);

        _resetSizeFactory(address(size2proxy));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MARKET.selector, address(size2proxy)));
        size2proxy.reinitialize(sizeFactory);
    }

    function test_ReinitializeV1_7_reinitialize_cannot_reinitialize_twice() public {
        size.reinitialize(sizeFactory);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        size.reinitialize(sizeFactory);
    }

    function test_ReinitializeV1_7_reinitialize_cannot_call_for_markets_deployed_after_v1_7() public {
        vm.store(address(size), SIZE_FACTORY_SLOT, bytes32(uint256(uint160(address(sizeFactory)))));
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        size.reinitialize(sizeFactory);
    }
}
