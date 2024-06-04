// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {UpdateConfigParams} from "@src/core/libraries/general/actions/UpdateConfig.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {KEEPER_ROLE} from "@src/core/Size.sol";
import {UserView} from "@src/core/SizeView.sol";

import {Deploy} from "@script/Deploy.sol";

struct Vars {
    UserView alice;
    UserView bob;
    UserView candy;
    UserView james;
    UserView liquidator;
    UserView variablePool;
    UserView size;
    UserView feeRecipient;
}

abstract contract BaseTestGeneral is Test, Deploy {
    address internal alice = address(0x10000);
    address internal bob = address(0x20000);
    address internal candy = address(0x30000);
    address internal james = address(0x40000);
    address internal liquidator = address(0x50000);
    address internal feeRecipient = address(0x70000);

    function setUp() public virtual {
        _labels();
        setupLocal(address(this), feeRecipient);
    }

    function _labels() internal {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
        vm.label(feeRecipient, "feeRecipient");

        vm.label(address(proxy), "size-proxy");
        vm.label(address(implementation), "size-implementation");
        vm.label(address(size), "size");
        vm.label(address(priceFeed), "priceFeed");
        vm.label(address(usdc), "usdc");
        vm.label(address(weth), "weth");
        vm.label(address(variablePool), "variablePool");

        vm.label(address(0), "address(0)");
    }

    function _mint(address token, address user, uint256 amount) internal {
        deal(token, user, amount);
    }

    function _approve(address user, address token, address spender, uint256 amount) internal {
        vm.prank(user);
        IERC20Metadata(token).approve(spender, amount);
    }

    function _state() internal view returns (Vars memory vars) {
        vars.alice = size.getUserView(alice);
        vars.bob = size.getUserView(bob);
        vars.candy = size.getUserView(candy);
        vars.james = size.getUserView(james);
        vars.liquidator = size.getUserView(liquidator);
        vars.variablePool = size.getUserView(address(variablePool));
        vars.size = size.getUserView(address(size));
        vars.feeRecipient = size.getUserView(feeRecipient);
    }

    function _setPrice(uint256 price) internal {
        vm.prank(address(this));
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function _setVariablePoolBorrowRate(uint128 rate) internal {
        vm.prank(address(this));
        size.setVariablePoolBorrowRate(rate);
    }

    function _updateConfig(string memory key, uint256 value) internal {
        vm.prank(address(this));
        size.updateConfig(UpdateConfigParams({key: key, value: value}));
    }

    function _setKeeperRole(address user) internal {
        vm.prank(address(this));
        size.grantRole(KEEPER_ROLE, user);
    }
}
