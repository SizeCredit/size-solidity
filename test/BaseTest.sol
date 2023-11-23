// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "../src/Size.sol";
import {SizeMock} from "./mocks/SizeMock.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {AssertsHelper} from "./helpers/AssertsHelper.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract BaseTest is Test, AssertsHelper {
    SizeMock public size;
    PriceFeedMock public priceFeed;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);

    struct Vars {
        User alice;
        User bob;
        User candy;
    }

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new SizeMock()),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                priceFeed,
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );
        size = SizeMock(address(proxy));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");

        priceFeed.setPrice(1337e18);
    }

    function _deposit(address user, uint256 cash, uint256 eth) internal {
        vm.prank(user);
        size.deposit(cash, eth);
    }

    function _lendAsLimitOrder(address lender, uint256 maxAmount, uint256 rate, uint256 maxDueDate) internal {
        vm.startPrank(lender);
        size.lendAsLimitOrder(maxAmount, maxDueDate, YieldCurveLibrary.getFlatRate(rate, maxDueDate));
    }

    function _borrowAsMarketOrder(address borrower, address lender, uint256 amount, uint256 dueDate)
        internal
        returns (uint256)
    {
        uint256[] memory virtualCollateralLoansIds;
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, virtualCollateralLoansIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoansIds
    ) internal returns (uint256) {
        vm.startPrank(borrower);
        size.borrowAsMarketOrder(lender, amount, dueDate, virtualCollateralLoansIds);
        return size.activeLoans();
    }

    function _borrowAsLimitOrder(
        address borrower,
        uint256 maxAmount,
        uint256[] memory timeBuckets,
        uint256[] memory rates
    ) internal {
        vm.startPrank(borrower);
        size.borrowAsLimitOrder(maxAmount, timeBuckets, rates);
    }

    function _exit(address user, uint256 loanId, uint256 amount, uint256 dueDate, address[] memory lendersToExitTo)
        internal
    {
        vm.startPrank(user);
        size.exit(loanId, amount, dueDate, lendersToExitTo);
    }

    function _getUsers() internal view returns (Vars memory vars) {
        vars.alice = size.getUser(alice);
        vars.bob = size.getUser(bob);
        vars.candy = size.getUser(candy);
    }
}
