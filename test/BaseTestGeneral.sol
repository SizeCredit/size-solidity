// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import {VariablePoolBorrowRateFeedMock} from "@test/mocks/VariablePoolBorrowRateFeedMock.sol";

import {DepositParams} from "@src/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/general/actions/Withdraw.sol";

import {KEEPER_ROLE} from "@src/Size.sol";
import {UserView} from "@src/SizeView.sol";

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
        setup(address(this), feeRecipient);
    }

    function _labels() internal {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
        vm.label(feeRecipient, "feeRecipient");

        vm.label(address(size), "size");
        vm.label(address(priceFeed), "priceFeed");
        vm.label(address(variablePoolBorrowRateFeed), "variablePoolBorrowRateFeed");
        vm.label(address(usdc), "usdc");
        vm.label(address(weth), "weth");
        vm.label(address(variablePool), "variablePool");
    }

    function _mint(address token, address user, uint256 amount) internal {
        deal(token, user, amount);
    }

    function _approve(address user, address token, address spender, uint256 amount) internal {
        vm.prank(user);
        IERC20Metadata(token).approve(spender, amount);
    }

    function _deposit(address user, IERC20Metadata token, uint256 amount) internal {
        _deposit(user, address(token), amount, user, false);
    }

    function _depositVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _deposit(user, address(token), amount, user, true);
    }

    function _deposit(address user, address token, uint256 amount, address to, bool variable) internal {
        _mint(token, user, amount);
        _approve(user, token, address(size), amount);
        vm.prank(user);
        size.deposit(DepositParams({token: token, amount: amount, to: to, variable: variable}));
    }

    function _withdraw(address user, IERC20Metadata token, uint256 amount) internal {
        _withdraw(user, address(token), amount, user, false);
    }

    function _withdrawVariable(address user, IERC20Metadata token, uint256 amount) internal {
        _withdraw(user, address(token), amount, user, true);
    }

    function _withdraw(address user, address token, uint256 amount, address to, bool variable) internal {
        vm.prank(user);
        size.withdraw(WithdrawParams({token: token, amount: amount, to: to, variable: variable}));
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

    function _setVariableBorrowRate(uint128 rate) internal {
        vm.prank(address(this));
        VariablePoolBorrowRateFeedMock(address(variablePoolBorrowRateFeed)).setVariableBorrowRate(rate);
    }

    function _updateConfig(bytes32 key, uint256 value) internal {
        vm.prank(address(this));
        size.updateConfig(UpdateConfigParams({key: key, value: value}));
    }

    function _setKeeperRole(address user) internal {
        vm.prank(address(this));
        size.grantRole(KEEPER_ROLE, user);
    }
}
