// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SizeV1_5} from "@src/deprecated/SizeV1_5.sol";
import {ISizeV1_5} from "@src/v1.5/interfaces/deprecated/ISizeV1_5.sol";

import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";
import {ForkReinitializeV1_5WethUsdcAfterCbbtcUsdcTest} from
    "@test/fork/v1.5/ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc.t.sol";

/// @notice Tests added by 0xAlix2
contract ForkReinitializeV1_5AuditWethUsdcAfterCbbtcUsdcWethUsdcAfterCbbtcUsdcTest is
    ForkReinitializeV1_5WethUsdcAfterCbbtcUsdcTest
{
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    IERC20Metadata internal USDC;
    IERC20Metadata internal WETH;
    IERC20Metadata internal CBBTC;
    SizeV1_5 internal v1_5;
    address[] internal WETH_USDC_users;
    address[] internal cBBTC_USDC_users;

    function _dealUSDC(address user, uint256 amount) internal {
        address whale = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.prank(whale);
        USDC.transfer(user, amount);
    }

    function _dealWETH(address user, uint256 amount) internal {
        address whale = 0x6446021F4E396dA3df4235C62537431372195D38;
        vm.prank(whale);
        WETH.transfer(user, amount);
    }

    function _dealCBBTC(address user, uint256 amount) internal {
        address whale = 0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6;
        vm.prank(whale);
        CBBTC.transfer(user, amount);
    }

    function testFork_ForkReinitializeV1_5AuditWethUsdcAfterCbbtcUsdc_LoanBeforeReinitializationRepayAfter() public {
        USDC = sizeWethUsdc.data().underlyingBorrowToken;
        WETH = sizeWethUsdc.data().underlyingCollateralToken;
        v1_5 = new SizeV1_5();

        importV1_5ReinitializeData("base-production-weth-usdc", addressesWethUsdc);
        WETH_USDC_users = addressesWethUsdc.keys();

        bob = WETH_USDC_users[2];
        alice = WETH_USDC_users[3];

        uint256 USDCamount = 100e6;
        uint256 WETHamount = 1e18;

        uint256 tenor = 365 days;

        _dealUSDC(bob, USDCamount);
        _dealWETH(alice, WETHamount);
        _dealUSDC(alice, USDCamount);

        {
            vm.startPrank(bob);
            USDC.approve(address(sizeWethUsdc), USDCamount);
            sizeWethUsdc.deposit(DepositParams({token: address(USDC), amount: USDCamount, to: bob}));
            sizeWethUsdc.buyCreditLimit(
                BuyCreditLimitParams({
                    maxDueDate: block.timestamp + tenor,
                    curveRelativeTime: YieldCurveHelper.pointCurve(tenor, 0.5e18)
                })
            );
            vm.stopPrank();
        }

        {
            vm.startPrank(alice);
            WETH.approve(address(sizeWethUsdc), WETHamount);
            sizeWethUsdc.deposit(DepositParams({token: address(WETH), amount: WETHamount, to: alice}));
            sizeWethUsdc.sellCreditMarket(
                SellCreditMarketParams({
                    lender: bob,
                    creditPositionId: type(uint256).max,
                    amount: USDCamount,
                    tenor: tenor,
                    deadline: block.timestamp,
                    maxAPR: type(uint256).max,
                    exactAmountIn: false
                })
            );
            vm.stopPrank();
        }

        {
            vm.startPrank(owner);
            UUPSUpgradeable(address(sizeWethUsdc)).upgradeToAndCall(
                address(v1_5), abi.encodeCall(ISizeV1_5.reinitialize, (address(newBorrowAToken), WETH_USDC_users))
            );
            vm.stopPrank();
        }

        vm.warp(block.timestamp + tenor);

        {
            vm.startPrank(alice);
            USDC.approve(address(sizeWethUsdc), USDC.balanceOf(alice));
            sizeWethUsdc.deposit(DepositParams({token: address(USDC), amount: USDC.balanceOf(alice), to: alice}));
            sizeWethUsdc.repay(
                RepayParams({debtPositionId: sizeWethUsdc.data().nextDebtPositionId - 1, borrower: alice})
            );
            vm.stopPrank();
        }

        {
            vm.startPrank(bob);
            sizeWethUsdc.claim(ClaimParams({creditPositionId: sizeWethUsdc.data().nextCreditPositionId - 1}));
            vm.stopPrank();
        }
    }

    function testFork_ForkReinitializeV1_5AuditWethUsdcAfterCbbtcUsdc_LoanOn2Markets() public {
        USDC = sizeWethUsdc.data().underlyingBorrowToken;
        WETH = sizeWethUsdc.data().underlyingCollateralToken;
        CBBTC = sizeCbbtcUsdc.data().underlyingCollateralToken;
        v1_5 = new SizeV1_5();

        importV1_5ReinitializeData("base-production-weth-usdc", addressesWethUsdc);
        WETH_USDC_users = addressesWethUsdc.keys();

        importV1_5ReinitializeData("base-production-cbbtc-usdc", addressesCbbtcUsdc);
        cBBTC_USDC_users = addressesCbbtcUsdc.keys();

        bob = WETH_USDC_users[2];
        alice = WETH_USDC_users[3];
        candy = cBBTC_USDC_users[3];

        uint256 USDCamount = 100e6;
        uint256 WETHamount = 1e18;
        uint256 CBBTCamount = 1e8;

        uint256 tenor = 365 days;

        _dealUSDC(bob, USDCamount);
        _dealWETH(alice, WETHamount);
        _dealUSDC(alice, USDCamount);
        _dealCBBTC(candy, CBBTCamount);
        _dealUSDC(candy, USDCamount);

        {
            vm.startPrank(bob);
            USDC.approve(address(sizeWethUsdc), USDCamount);
            sizeWethUsdc.deposit(DepositParams({token: address(USDC), amount: USDCamount, to: bob}));
            sizeWethUsdc.buyCreditLimit(
                BuyCreditLimitParams({
                    maxDueDate: block.timestamp + tenor,
                    curveRelativeTime: YieldCurveHelper.pointCurve(tenor, 0.5e18)
                })
            );
            sizeCbbtcUsdc.buyCreditLimit(
                BuyCreditLimitParams({
                    maxDueDate: block.timestamp + tenor,
                    curveRelativeTime: YieldCurveHelper.pointCurve(tenor, 0.5e18)
                })
            );
            vm.stopPrank();
        }

        vm.startPrank(owner);
        {
            UUPSUpgradeable(address(sizeWethUsdc)).upgradeToAndCall(
                address(v1_5), abi.encodeCall(ISizeV1_5.reinitialize, (address(newBorrowAToken), WETH_USDC_users))
            );
        }
        vm.stopPrank();

        uint256 bobCreditPositionId = sizeWethUsdc.data().nextCreditPositionId;
        uint256 aliceDebtPositionId = sizeWethUsdc.data().nextDebtPositionId;
        {
            vm.startPrank(alice);
            WETH.approve(address(sizeWethUsdc), WETHamount);
            sizeWethUsdc.deposit(DepositParams({token: address(WETH), amount: WETHamount, to: alice}));
            sizeWethUsdc.sellCreditMarket(
                SellCreditMarketParams({
                    lender: bob,
                    creditPositionId: type(uint256).max,
                    amount: USDCamount / 2,
                    tenor: tenor,
                    deadline: block.timestamp,
                    maxAPR: type(uint256).max,
                    exactAmountIn: false
                })
            );
            vm.stopPrank();
        }

        uint256 bobCreditPositionId2 = sizeCbbtcUsdc.data().nextCreditPositionId;
        uint256 candyDebtPositionId = sizeCbbtcUsdc.data().nextDebtPositionId;
        {
            vm.startPrank(candy);
            CBBTC.approve(address(sizeCbbtcUsdc), CBBTCamount);
            sizeCbbtcUsdc.deposit(DepositParams({token: address(CBBTC), amount: CBBTCamount, to: candy}));
            sizeCbbtcUsdc.sellCreditMarket(
                SellCreditMarketParams({
                    lender: bob,
                    creditPositionId: type(uint256).max,
                    amount: USDCamount / 2,
                    tenor: tenor,
                    deadline: block.timestamp,
                    maxAPR: type(uint256).max,
                    exactAmountIn: false
                })
            );
            vm.stopPrank();
        }

        vm.warp(block.timestamp + tenor);

        {
            vm.startPrank(alice);
            USDC.approve(address(sizeWethUsdc), USDC.balanceOf(alice));
            sizeWethUsdc.deposit(DepositParams({token: address(USDC), amount: USDC.balanceOf(alice), to: alice}));
            sizeWethUsdc.repay(RepayParams({debtPositionId: aliceDebtPositionId, borrower: alice}));
            vm.stopPrank();
        }

        {
            vm.startPrank(candy);
            USDC.approve(address(sizeCbbtcUsdc), USDC.balanceOf(candy));
            sizeCbbtcUsdc.deposit(DepositParams({token: address(USDC), amount: USDC.balanceOf(candy), to: candy}));
            sizeCbbtcUsdc.repay(RepayParams({debtPositionId: candyDebtPositionId, borrower: candy}));
            vm.stopPrank();
        }

        {
            vm.startPrank(bob);
            sizeWethUsdc.claim(ClaimParams({creditPositionId: bobCreditPositionId}));
            sizeCbbtcUsdc.claim(ClaimParams({creditPositionId: bobCreditPositionId2}));
            vm.stopPrank();
        }
    }

    function testFork_ForkReinitializeV1_5AuditWethUsdcAfterCbbtcUsdc_ATokenDonationReinitializeDOS() public {
        USDC = sizeWethUsdc.data().underlyingBorrowToken;
        IAToken aUSDC = IAToken(sizeWethUsdc.data().variablePool.getReserveData(address(USDC)).aTokenAddress);

        address aUSDC_holder = 0x4E32E08f3d8d1cAb474A489B4E31f8D3FD627abf;

        vm.prank(aUSDC_holder);
        aUSDC.transfer(address(sizeWethUsdc), 1e6);

        testFork_ForkReinitializeV1_5WethUsdcAfterCbbtcUsdc_migrate_WETH_USDC();
    }
}
