// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {SizeV1_5} from "@src/deprecated/SizeV1_5.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_5} from "@src/v1.5/interfaces/deprecated/ISizeV1_5.sol";

import {NonTransferrableScaledTokenV1_2} from "@src/token/deprecated/NonTransferrableScaledTokenV1_2.sol";
import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";

import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";
import {console2 as console} from "forge-std/console2.sol";

contract ForkReinitializeV1_5Test is ForkTest {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 internal BLOCK_NUMBER = 22746717;

    ISize internal sizeWethUsdc;
    ISize internal sizeCbbtcUsdc;
    IPriceFeed internal priceFeedWethUsdc;
    IPriceFeed internal priceFeedCbbtcUsdc;
    EnumerableMap.AddressToUintMap internal addressesWethUsdc;
    EnumerableMap.AddressToUintMap internal addressesCbbtcUsdc;
    bytes internal dataWethUsdc;
    bytes internal dataCbbtcUsdc;

    NonTransferrableScaledTokenV1_5 internal newBorrowAToken;

    struct Supply {
        uint256 totalSupply;
        uint256 scaledTotalSupply;
    }

    struct Vars {
        uint256 balanceBefore;
        uint256 balanceBeforeSizeWethUsdc;
        uint256 balanceBeforeSizeCbbtcUsdc;
        uint256 balanceAfter;
        uint256 balanceAfterSizeWethUsdc;
        uint256 balanceAfterSizeCbbtcUsdc;
        uint256 balanceBeforeWithdraw;
        uint256 balanceAfterWithdraw;
        uint256 balanceAfterSizeWethUsdcWithdraw;
        uint256 balanceAfterSizeCbbtcUsdcWithdraw;
        uint256 underlyingBalanceBeforeWithdraw;
        uint256 underlyingBalanceAfterWithdraw;
    }

    function setUp() public override {
        vm.createSelectFork("base");
        vm.rollFork(BLOCK_NUMBER);

        address sizeWethUsdcOwner;
        address sizeCbbtcUsdcOwner;

        (sizeWethUsdc, priceFeedWethUsdc, sizeWethUsdcOwner) = importDeployments("base-production-weth-usdc");
        (sizeCbbtcUsdc, priceFeedCbbtcUsdc, sizeCbbtcUsdcOwner) = importDeployments("base-production-cbbtc-usdc");

        IERC20Metadata sizeWethUsdcBorrowToken = sizeWethUsdc.data().underlyingBorrowToken;
        IERC20Metadata sizeCbbtcUsdcBorrowToken = sizeCbbtcUsdc.data().underlyingBorrowToken;

        IPool sizeWethUsdcVariablePool = sizeWethUsdc.data().variablePool;
        IPool sizeCbbtcUsdcVariablePool = sizeCbbtcUsdc.data().variablePool;

        assertEq(sizeWethUsdcOwner, sizeCbbtcUsdcOwner);
        assertEq(address(sizeWethUsdcVariablePool), address(sizeCbbtcUsdcVariablePool));
        assertEq(address(sizeWethUsdcBorrowToken), address(sizeCbbtcUsdcBorrowToken));

        owner = sizeWethUsdcOwner;
        variablePool = sizeWethUsdcVariablePool;
        borrowToken = sizeWethUsdcBorrowToken;
        uint256 blockNumberWethUsdc;
        uint256 blockNumberCbbtcUsdc;
        (blockNumberWethUsdc, dataWethUsdc) = importV1_5ReinitializeData("base-production-weth-usdc", addressesWethUsdc);
        (blockNumberCbbtcUsdc, dataCbbtcUsdc) =
            importV1_5ReinitializeData("base-production-cbbtc-usdc", addressesCbbtcUsdc);
        assertEq(blockNumberWethUsdc, blockNumberCbbtcUsdc, BLOCK_NUMBER);
    }

    function _deployNewBorrowAToken() internal {
        newBorrowAToken = _deployBorrowAToken(owner, ISizeFactory(sizeFactory), variablePool, borrowToken);
    }

    function testFork_ForkReinitializeV1_5_migrate_WETH_USDC() public {
        sizeFactory = _deploySizeFactory(owner);
        _deployNewBorrowAToken();

        string memory market = "base-production-weth-usdc";
        ISize isize = sizeWethUsdc;
        IPriceFeed ipriceFeed = priceFeedWethUsdc;
        EnumerableMap.AddressToUintMap storage addresses = addressesWethUsdc;

        Supply memory old;
        _testFork_ForkReinitializeV1_5_migrate(market, isize, ipriceFeed, addresses, old, true);
    }

    function testFork_ForkReinitializeV1_5_migrate_cBBTC_USDC() public {
        sizeFactory = _deploySizeFactory(owner);
        _deployNewBorrowAToken();

        string memory market = "base-production-cbbtc-usdc";
        ISize isize = sizeCbbtcUsdc;
        IPriceFeed ipriceFeed = priceFeedCbbtcUsdc;
        EnumerableMap.AddressToUintMap storage addresses = addressesCbbtcUsdc;

        Supply memory old;
        _testFork_ForkReinitializeV1_5_migrate(market, isize, ipriceFeed, addresses, old, true);
    }

    function testFork_ForkReinitializeV1_5_migrate_2_existing_markets() public {
        sizeFactory = _deploySizeFactory(owner);
        _deployNewBorrowAToken();

        string[2] memory markets = ["base-production-weth-usdc", "base-production-cbbtc-usdc"];
        IPriceFeed[2] memory ipriceFeeds = [priceFeedWethUsdc, priceFeedCbbtcUsdc];
        ISize[2] memory sizes = [sizeWethUsdc, sizeCbbtcUsdc];
        Supply memory old;
        for (uint256 i = 0; i < markets.length; i++) {
            ISize isize = sizes[i];
            IPriceFeed ipriceFeed = ipriceFeeds[i];
            string memory market = markets[i];
            EnumerableMap.AddressToUintMap storage addresses = i == 0 ? addressesWethUsdc : addressesCbbtcUsdc;

            _testFork_ForkReinitializeV1_5_migrate(market, isize, ipriceFeed, addresses, old, false);
        }
    }

    function _testFork_ForkReinitializeV1_5_migrate(
        string memory market,
        ISize isize,
        IPriceFeed ipriceFeed,
        EnumerableMap.AddressToUintMap storage addresses,
        Supply memory old,
        bool withdraw
    ) internal {
        address[] memory users = addresses.keys();

        console.log("Market: %s, Users: %s", market, users.length);

        vm.prank(owner);
        sizeFactory.addMarket(isize);
        vm.prank(owner);
        sizeFactory.addPriceFeed(PriceFeed(address(ipriceFeed)));
        vm.prank(owner);
        sizeFactory.addBorrowATokenV1_5(newBorrowAToken);

        NonTransferrableScaledTokenV1_2 borrowATokenV1_2 =
            NonTransferrableScaledTokenV1_2(address(isize.data().borrowAToken));

        old.totalSupply += borrowATokenV1_2.totalSupply();
        old.scaledTotalSupply += borrowATokenV1_2.scaledTotalSupply();

        SizeV1_5 v1_5 = new SizeV1_5();

        vm.prank(owner);
        UUPSUpgradeable(address(isize)).upgradeToAndCall(
            address(v1_5), abi.encodeCall(ISizeV1_5.reinitialize, (address(newBorrowAToken), users))
        );

        assertEq(address(isize.data().borrowAToken), address(newBorrowAToken), "borrowAToken should be newBorrowAToken");

        assertEq(borrowATokenV1_2.totalSupply(), 0, "totalSupply should be 0");
        assertEq(borrowATokenV1_2.scaledTotalSupply(), 0, "scaledTotalSupply should be 0");
        assertEq(
            newBorrowAToken.scaledTotalSupply(),
            old.scaledTotalSupply,
            "new scaledTotalSupply = SUM(old scaledTotalSupply)"
        );
        assertEqApprox(newBorrowAToken.totalSupply(), old.totalSupply, 1, "new totalSupply = SUM(old totalSupply)");

        console.log("Migration completed for market: %s", market);

        if (withdraw) {
            for (uint256 i = 0; i < users.length; i++) {
                address user = users[i];
                uint256 oldBalance = addresses.get(user);
                uint256 newBalance = newBorrowAToken.balanceOf(user);

                assertEq(newBalance, oldBalance, "newBalance == oldBalance");

                uint256 balanceBefore = borrowToken.balanceOf(user);

                vm.prank(user);
                isize.withdraw(WithdrawParams({token: address(borrowToken), amount: newBalance, to: user}));

                uint256 balanceAfter = borrowToken.balanceOf(user);
                assertEq(balanceAfter, balanceBefore + newBalance, "users can withdraw everything");
            }
        }
    }

    function _getUserWhoHadDepositsInBothMarkets() private view returns (address userWhoHadDepositsInBothMarkets) {
        for (uint256 i = 0; i < addressesWethUsdc.length(); i++) {
            (address user,) = addressesWethUsdc.at(i);
            if (addressesCbbtcUsdc.contains(user)) {
                userWhoHadDepositsInBothMarkets = user;
                break;
            }
        }
        assertTrue(userWhoHadDepositsInBothMarkets != address(0), "userWhoHadDepositsInBothMarkets != address(0)");
    }

    function testFork_ForkReinitializeV1_5_deposit_withdraw_after_migrate() public {
        testFork_ForkReinitializeV1_5_migrate_2_existing_markets();

        address userWhoHadDepositsInBothMarkets = _getUserWhoHadDepositsInBothMarkets();

        IERC20Metadata underlyingBorrowToken = sizeWethUsdc.data().underlyingBorrowToken;

        uint256 amount = underlyingBorrowToken.balanceOf(userWhoHadDepositsInBothMarkets);
        assertGt(amount, 0, "userWhoHadDepositsInBothMarkets has balance");

        Vars memory vars;

        vars.balanceBefore = newBorrowAToken.balanceOf(userWhoHadDepositsInBothMarkets);
        vars.balanceBeforeSizeWethUsdc = sizeWethUsdc.getUserView(userWhoHadDepositsInBothMarkets).borrowATokenBalance;
        vars.balanceBeforeSizeCbbtcUsdc = sizeCbbtcUsdc.getUserView(userWhoHadDepositsInBothMarkets).borrowATokenBalance;
        assertEq(vars.balanceBeforeSizeWethUsdc, vars.balanceBeforeSizeCbbtcUsdc, vars.balanceBefore);

        vm.prank(userWhoHadDepositsInBothMarkets);
        underlyingBorrowToken.approve(address(sizeWethUsdc), amount);
        vm.prank(userWhoHadDepositsInBothMarkets);
        sizeWethUsdc.deposit(
            DepositParams({token: address(underlyingBorrowToken), amount: amount, to: userWhoHadDepositsInBothMarkets})
        );

        vars.balanceAfter = newBorrowAToken.balanceOf(userWhoHadDepositsInBothMarkets);
        vars.balanceAfterSizeWethUsdc = sizeWethUsdc.getUserView(userWhoHadDepositsInBothMarkets).borrowATokenBalance;
        vars.balanceAfterSizeCbbtcUsdc = sizeCbbtcUsdc.getUserView(userWhoHadDepositsInBothMarkets).borrowATokenBalance;
        assertEq(
            vars.balanceAfterSizeWethUsdc,
            vars.balanceAfterSizeCbbtcUsdc,
            vars.balanceAfter,
            "user has balance in newBorrowAToken"
        );

        assertEq(vars.balanceAfter, vars.balanceBefore + amount, "user can deposit");

        vars.underlyingBalanceBeforeWithdraw = underlyingBorrowToken.balanceOf(userWhoHadDepositsInBothMarkets);

        vm.prank(userWhoHadDepositsInBothMarkets);
        sizeWethUsdc.withdraw(
            WithdrawParams({token: address(underlyingBorrowToken), amount: amount, to: userWhoHadDepositsInBothMarkets})
        );

        vars.underlyingBalanceAfterWithdraw = underlyingBorrowToken.balanceOf(userWhoHadDepositsInBothMarkets);
        assertEq(
            vars.underlyingBalanceAfterWithdraw, vars.underlyingBalanceBeforeWithdraw + amount, "user can withdraw"
        );

        vars.balanceAfterWithdraw = newBorrowAToken.balanceOf(userWhoHadDepositsInBothMarkets);
        vars.balanceAfterSizeWethUsdcWithdraw =
            sizeWethUsdc.getUserView(userWhoHadDepositsInBothMarkets).borrowATokenBalance;
        vars.balanceAfterSizeCbbtcUsdcWithdraw =
            sizeCbbtcUsdc.getUserView(userWhoHadDepositsInBothMarkets).borrowATokenBalance;
        assertEq(
            vars.balanceAfterSizeWethUsdcWithdraw, vars.balanceAfterSizeCbbtcUsdcWithdraw, vars.balanceAfterWithdraw
        );
    }

    function testFork_ForkReinitializeV1_5_cannot_be_DoS_by_donation_attack() public {
        address userWhoHadDepositsInBothMarkets = _getUserWhoHadDepositsInBothMarkets();

        IPool variablePool = sizeWethUsdc.data().variablePool;

        uint256 amount = 1;

        vm.prank(userWhoHadDepositsInBothMarkets);
        borrowToken.approve(address(variablePool), amount);
        vm.prank(userWhoHadDepositsInBothMarkets);
        variablePool.supply(address(borrowToken), amount, address(sizeWethUsdc), 0);

        testFork_ForkReinitializeV1_5_migrate_2_existing_markets();
    }

    function testFork_ForkReinitializeV1_5_works_with_data() public {
        SizeV1_5 v1_5 = new SizeV1_5();

        vm.prank(owner);
        UUPSUpgradeable(address(sizeWethUsdc)).upgradeToAndCall(address(v1_5), dataWethUsdc);

        vm.prank(owner);
        UUPSUpgradeable(address(sizeCbbtcUsdc)).upgradeToAndCall(address(v1_5), dataCbbtcUsdc);
    }
}
