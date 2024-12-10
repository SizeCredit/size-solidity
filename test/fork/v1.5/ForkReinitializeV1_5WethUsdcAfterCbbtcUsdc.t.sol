// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Size} from "@src/Size.sol";
import {ISize} from "@src/interfaces/ISize.sol";

import {NonTransferrableScaledTokenV1_2} from "@src/token/deprecated/NonTransferrableScaledTokenV1_2.sol";

import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";
import {console2 as console} from "forge-std/console2.sol";

contract ForkReinitializeV1_5WethUsdcAfterCbbtcUsdcTest is ForkTest {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 internal BLOCK_NUMBER_CBBTC_USDC_ALREADY_MIGRATED = 22878761;

    ISize internal sizeWethUsdc;
    ISize internal sizeCbbtcUsdc;
    EnumerableMap.AddressToUintMap internal addressesWethUsdc;
    EnumerableMap.AddressToUintMap internal addressesCbbtcUsdc;
    EnumerableMap.AddressToUintMap internal oldScaledBalancesWethUsdc;
    EnumerableMap.AddressToUintMap internal newScaledBalancesWethUsdc;
    bytes internal dataWethUsdc;

    NonTransferrableScaledTokenV1_5 internal newBorrowAToken;

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
        vm.rollFork(BLOCK_NUMBER_CBBTC_USDC_ALREADY_MIGRATED);

        address sizeWethUsdcOwner;
        address sizeCbbtcUsdcOwner;

        (sizeWethUsdc,, sizeWethUsdcOwner) = importDeployments("base-production-weth-usdc");
        (sizeCbbtcUsdc,, sizeCbbtcUsdcOwner) = importDeployments("base-production-cbbtc-usdc");

        assertTrue(Strings.equal(sizeCbbtcUsdc.version(), "v1.5"));
        assertTrue(!Strings.equal(sizeWethUsdc.version(), "v1.5"));

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
        (blockNumberWethUsdc, dataWethUsdc) =
            importV1_5ReinitializeData("base-production-weth-usdc-after-cbbtc-usdc", addressesWethUsdc);
        (blockNumberCbbtcUsdc,) = importV1_5ReinitializeData("base-production-cbbtc-usdc", addressesCbbtcUsdc);
        assertLt(blockNumberCbbtcUsdc, BLOCK_NUMBER_CBBTC_USDC_ALREADY_MIGRATED);
        assertEq(blockNumberWethUsdc, BLOCK_NUMBER_CBBTC_USDC_ALREADY_MIGRATED);

        sizeFactory = importSizeFactory("base-production-size-factory");
        newBorrowAToken = NonTransferrableScaledTokenV1_5(address(sizeFactory.getBorrowATokensV1_5()[0]));
    }

    function testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_initialized() public {
        assertTrue(
            address(sizeWethUsdc.data().borrowAToken) != address(newBorrowAToken),
            "borrowAToken should not yet be newBorrowAToken"
        );
        assertTrue(
            address(sizeCbbtcUsdc.data().borrowAToken) == address(newBorrowAToken),
            "borrowAToken should be newBorrowAToken"
        );
    }

    function testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_migrate_WETH_USDC() public {
        string memory market = "base-production-weth-usdc";
        ISize isize = sizeWethUsdc;
        EnumerableMap.AddressToUintMap storage addresses = addressesWethUsdc;

        uint256 scaledTotalSupply;
        address[] memory users = addresses.keys();

        console.log("Market: %s, Users: %s", market, users.length);

        NonTransferrableScaledTokenV1_2 borrowATokenV1_2 =
            NonTransferrableScaledTokenV1_2(address(isize.data().borrowAToken));

        scaledTotalSupply += borrowATokenV1_2.scaledTotalSupply();
        uint256 newBorrowATokenScaledTotalSupplyBefore = newBorrowAToken.scaledTotalSupply();
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            oldScaledBalancesWethUsdc.set(user, borrowATokenV1_2.scaledBalanceOf(user));
            newScaledBalancesWethUsdc.set(user, newBorrowAToken.scaledBalanceOf(user));
        }

        Size v1_5 = new Size();

        vm.prank(owner);
        UUPSUpgradeable(address(isize)).upgradeToAndCall(
            address(v1_5), abi.encodeCall(Size.reinitialize, (address(newBorrowAToken), users))
        );

        assertEq(address(isize.data().borrowAToken), address(newBorrowAToken), "borrowAToken should be newBorrowAToken");

        assertEq(borrowATokenV1_2.totalSupply(), 0, "totalSupply should be 0");
        assertEq(borrowATokenV1_2.scaledTotalSupply(), 0, "scaledTotalSupply should be 0");
        assertGe(
            newBorrowAToken.scaledTotalSupply(),
            newBorrowATokenScaledTotalSupplyBefore + scaledTotalSupply,
            "new scaledTotalSupply delta = SUM(old scaledTotalSupply)"
        );

        console.log("Migration completed for market: %s", market);

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 balance = newBorrowAToken.balanceOf(user);

            assertEq(
                oldScaledBalancesWethUsdc.get(user) + newScaledBalancesWethUsdc.get(user),
                newBorrowAToken.scaledBalanceOf(user)
            );

            uint256 balanceBefore = borrowToken.balanceOf(user);

            vm.prank(user);
            isize.withdraw(WithdrawParams({token: address(borrowToken), amount: balance, to: user}));

            uint256 balanceAfter = borrowToken.balanceOf(user);
            assertEq(balanceAfter, balanceBefore + balance, "users can withdraw everything");
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

    function testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_deposit_withdraw_after_migrate() public {
        testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_migrate_WETH_USDC();

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

        assertEqApprox(vars.balanceAfter, vars.balanceBefore + amount, 1, "user can deposit");

        vars.underlyingBalanceBeforeWithdraw = underlyingBorrowToken.balanceOf(userWhoHadDepositsInBothMarkets);

        vm.prank(userWhoHadDepositsInBothMarkets);
        sizeWethUsdc.withdraw(
            WithdrawParams({token: address(underlyingBorrowToken), amount: amount, to: userWhoHadDepositsInBothMarkets})
        );

        vars.underlyingBalanceAfterWithdraw = underlyingBorrowToken.balanceOf(userWhoHadDepositsInBothMarkets);
        assertEqApprox(
            vars.underlyingBalanceAfterWithdraw, vars.underlyingBalanceBeforeWithdraw + amount, 1, "user can withdraw"
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

    function testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_cannot_be_DoS_by_donation_attack() public {
        address userWhoHadDepositsInBothMarkets = _getUserWhoHadDepositsInBothMarkets();

        IPool variablePool = sizeWethUsdc.data().variablePool;

        uint256 amount = 1;

        vm.prank(userWhoHadDepositsInBothMarkets);
        borrowToken.approve(address(variablePool), amount);
        vm.prank(userWhoHadDepositsInBothMarkets);
        variablePool.supply(address(borrowToken), amount, address(sizeWethUsdc), 0);

        testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_migrate_WETH_USDC();
    }

    function testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_works_with_data() public {
        Size v1_5 = new Size();

        vm.prank(owner);
        UUPSUpgradeable(address(sizeWethUsdc)).upgradeToAndCall(address(v1_5), dataWethUsdc);
    }
}
