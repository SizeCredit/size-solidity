// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2 as console} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "../src/Size.sol";
import {SizeMock} from "./mocks/SizeMock.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {AssertsHelper} from "./helpers/AssertsHelper.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {WETH} from "./mocks/WETH.sol";
import {USDC} from "./mocks/USDC.sol";

contract BaseTest is Test, AssertsHelper {
    event TODO();

    SizeMock public size;
    PriceFeedMock public priceFeed;
    WETH public weth;
    USDC public usdc;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);
    address public protocol;

    struct Vars {
        User alice;
        User bob;
        User candy;
        User liquidator;
        User protocol;
    }

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        weth = new WETH();
        usdc = new USDC();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new SizeMock()),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                address(priceFeed),
                address(weth),
                address(usdc),
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );
        protocol = address(proxy);
        size = SizeMock(address(proxy));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
        vm.label(protocol, "protocol");

        priceFeed.setPrice(1337e18);
    }

    function _deposit(address user, address token, uint256 value) internal {
        deal(token, user, value);
        vm.prank(user);
        size.deposit(token, value);
    }

    function _withdraw(address user, address token, uint256 value) internal {
        vm.prank(user);
        size.withdraw(token, value);
    }

    function _deposit(address user, uint256 collateralAssetValue, uint256 debtAssetValue) internal {
        _deposit(user, address(weth), collateralAssetValue);
        _deposit(user, address(usdc), debtAssetValue);
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256 rate,
        uint256 timeBucketsLength
    ) internal {
        YieldCurve memory curve = YieldCurveLibrary.getFlatRate(timeBucketsLength, rate);
        vm.prank(lender);
        size.lendAsLimitOrder(maxAmount, maxDueDate, curve.timeBuckets, curve.rates);
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
        vm.prank(borrower);
        size.borrowAsMarketOrder(lender, amount, dueDate, virtualCollateralLoansIds);
        return size.activeLoans();
    }

    function _borrowAsLimitOrder(
        address borrower,
        uint256 maxAmount,
        uint256[] memory timeBuckets,
        uint256[] memory rates
    ) internal {
        vm.prank(borrower);
        size.borrowAsLimitOrder(maxAmount, timeBuckets, rates);
    }

    function _exit(address user, uint256 loanId, uint256 amount, uint256 dueDate, address[] memory lendersToExitTo)
        internal
    {
        vm.prank(user);
        size.exit(loanId, amount, dueDate, lendersToExitTo);
    }

    function _repay(address user, uint256 loanId) internal {
        vm.prank(user);
        size.repay(loanId);
    }

    function _claim(address user, uint256 loanId) internal {
        vm.prank(user);
        size.claim(loanId);
    }

    function _liquidateLoan(address user, uint256 loanId) internal {
        vm.prank(user);
        size.liquidateLoan(loanId);
    }

    function _getUsers() internal view returns (Vars memory vars) {
        vars.alice = size.getUser(alice);
        vars.bob = size.getUser(bob);
        vars.candy = size.getUser(candy);
        vars.liquidator = size.getUser(liquidator);
        vars.protocol = size.getUser(protocol);
    }

    function _setPrice(uint256 price) internal {
        vm.prank(address(this));
        priceFeed.setPrice(price);
    }
}
