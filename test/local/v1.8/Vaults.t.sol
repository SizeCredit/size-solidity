// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {console} from "forge-std/console.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {PERCENT} from "@src/market/libraries/Math.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";

import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {SetVaultParams} from "@src/market/libraries/actions/SetVault.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ERC4626 as ERC4626OpenZeppelin} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {ERC20 as ERC20Solady} from "@solady/src/tokens/ERC20.sol";
import {ERC4626 as ERC4626Solady} from "@solady/src/tokens/ERC4626.sol";
import {MockERC4626} from "@solady/test/utils/mocks/MockERC4626.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";

import {ControlledAsyncDeposit} from "@ERC-7540-Reference/src/ControlledAsyncDeposit.sol";
import {ControlledAsyncRedeem} from "@ERC-7540-Reference/src/ControlledAsyncRedeem.sol";
import {FullyAsyncVault} from "@ERC-7540-Reference/src/FullyAsyncVault.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {FeeOnEntryExitERC4626} from "@test/mocks/vaults/FeeOnEntryExitERC4626.sol";
import {FeeOnTransferERC4626} from "@test/mocks/vaults/FeeOnTransferERC4626.sol";
import {LimitsERC4626} from "@test/mocks/vaults/LimitsERC4626.sol";
import {MaliciousERC4626} from "@test/mocks/vaults/MaliciousERC4626.sol";
import {ReentrancyMaliciousERC4626} from "@test/mocks/vaults/ReentrancyMaliciousERC4626.sol";

import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

contract VaultsTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _deploySizeMarket2();
    }

    function test_Vaults_borrower_vault_lender_aave() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVault(bob, address(vault), false);

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_Vaults_borrower_aave_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVault(alice, address(vault), false);

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_Vaults_borrower_vault_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVault(alice, address(vault), false);
        _setVault(bob, address(vault), false);

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_Vaults_borrower_aave_lender_changes_vault_2_times_after_repay() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVault(alice, address(vault), false);
        _setVault(bob, address(vault), false);

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _deposit(bob, usdc, 100e6);
        _repay(bob, debtPositionId, bob);

        _setVault(alice, address(0), false);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vault2)));
        _setVault(alice, address(vault2), false);

        _claim(alice, creditPositionId);
    }

    function test_Vaults_lender_vault_low_liquidity() public {
        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVault(alice, address(vault), false);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        // vault loses liquidity
        deal(address(usdc), address(vault), 99e6);

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        vm.expectRevert(abi.encodeWithSelector(ERC4626Solady.WithdrawMoreThanMax.selector));
        vm.prank(bob);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        uint256 balanceBefore = usdc.balanceOf(alice);

        // user can still withdraw from vault with low liquidity
        _withdraw(alice, address(usdc), 100e6);

        assertEq(usdc.balanceOf(alice), balanceBefore + 99e6, "user should have received only available liquidity");
    }

    function test_Vaults_malicious_vault() public {
        _setVaultAdapter(vaultMalicious, "ERC4626Adapter");
        _setVault(alice, address(vaultMalicious), false);

        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        vm.expectRevert(abi.encodeWithSelector(MaliciousERC4626.WithdrawNotAllowed.selector));
        vm.prank(bob);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }

    function test_Vaults_fee_on_transfer_vault() public {
        _updateConfig("swapFeeAPR", 0);

        _setVaultAdapter(vaultFeeOnTransfer, "ERC4626Adapter");
        _setVault(alice, address(vaultFeeOnTransfer), false);

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);

        address borrowTokenVault = address(size.data().borrowTokenVault);
        address owner = address(FeeOnTransferERC4626(address(vaultFeeOnTransfer)).owner());

        vm.expectEmit(address(vaultFeeOnTransfer));
        emit IERC20.Transfer(address(0), borrowTokenVault, 200e6);
        emit IERC20.Transfer(borrowTokenVault, address(0), 20e6);
        emit IERC20.Transfer(address(0), owner, 20e6);
        vm.expectEmit(address(size));
        emit Events.Deposit(alice, alice, address(usdc), alice, 180e6);
        vm.prank(alice);
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));

        assertEq(_state().alice.borrowTokenBalance, 180e6);
        assertEq(usdc.balanceOf(address(vaultFeeOnTransfer)), 200e6);
        assertEq(vaultFeeOnTransfer.balanceOf(address(borrowTokenVault)), 180e6);
        assertEq(vaultFeeOnTransfer.balanceOf(address(owner)), 20e6);

        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        uint256 feeOnTransfer = amount / 10;

        Vars memory _before = _state();

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);

        Vars memory _after = _state();

        assertEq(
            _after.bob.borrowTokenBalance,
            _before.bob.borrowTokenBalance + amount,
            "bob should have received the amount"
        );
        assertEq(
            _after.alice.borrowTokenBalance,
            _before.alice.borrowTokenBalance - amount - feeOnTransfer,
            "alice should have sent the amount minus the fee"
        );
        assertEq(usdc.balanceOf(address(vaultFeeOnTransfer)), 100e6);
        assertEq(vaultFeeOnTransfer.balanceOf(address(borrowTokenVault)), 70e6);
        assertEq(vaultFeeOnTransfer.balanceOf(address(owner)), 30e6);
    }

    function test_Vaults_vault_with_wrong_underlying() public {
        NonTransferrableRebasingTokenVault borrowTokenVault =
            NonTransferrableRebasingTokenVault(address(size.data().borrowTokenVault));
        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vaultInvalidUnderlying)));
        borrowTokenVault.setVaultAdapter(address(vaultInvalidUnderlying), "ERC4626Adapter");

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vaultInvalidUnderlying)));
        _setVault(alice, address(vaultInvalidUnderlying), false);
    }

    function test_Vaults_non_erc4626_contract() public {
        NonTransferrableRebasingTokenVault borrowTokenVault =
            NonTransferrableRebasingTokenVault(address(size.data().borrowTokenVault));
        vm.prank(address(this));
        vm.expectRevert();
        borrowTokenVault.setVaultAdapter(address(vaultNonERC4626), "ERC4626Adapter");

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vaultNonERC4626)));
        _setVault(alice, address(vaultNonERC4626), false);
    }

    function test_Vaults_erc7540_fully_async_contract() public {
        // fully async ERC7540 vaults revert on deposit/withdraw

        _setVaultAdapter(vaultERC7540FullyAsync, "ERC4626Adapter");
        _setVault(alice, address(vaultERC7540FullyAsync), false);

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);
        vm.prank(alice);
        vm.expectRevert();
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));
    }

    function test_Vaults_erc7540_controlled_async_deposit_contract() public {
        // controlled async deposit ERC7540 vaults revert on deposit

        _setVaultAdapter(vaultERC7540ControlledAsyncDeposit, "ERC4626Adapter");
        _setVault(alice, address(vaultERC7540ControlledAsyncDeposit), false);

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);
        vm.prank(alice);
        vm.expectRevert();
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));
    }

    function test_Vaults_erc7540_controlled_async_redeem_contract() public {
        // controlled async redeem ERC7540 vaults revert on withdraw

        _updateConfig("swapFeeAPR", 0);

        _setVaultAdapter(vaultERC7540ControlledAsyncRedeem, "ERC4626Adapter");
        _setVault(alice, address(vaultERC7540ControlledAsyncRedeem), false);
        _setVault(bob, address(vaultERC7540ControlledAsyncRedeem), false);
        _setVault(size.feeConfig().feeRecipient, address(vaultERC7540ControlledAsyncRedeem), false);

        Vars memory _before = _state();

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);
        vm.prank(alice);
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + 200e6);

        _deposit(bob, weth, 100e18);
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _before = _state();

        // buyCreditMarket tried to be used to "exit" from vaults that revert on withdraw
        vm.expectRevert(
            abi.encodeWithSelector(
                IAdapter.InsufficientAssets.selector, address(vaultERC7540ControlledAsyncRedeem), 0, 100e6
            )
        );
        vm.prank(alice);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance);

        _withdraw(bob, address(usdc), 100e6);
    }

    function test_Vaults_limits_vault() public {
        _setVaultAdapter(vaultLimits, "ERC4626Adapter");
        _setVault(alice, address(vaultLimits), false);
        _setVault(bob, address(vaultLimits), false);
        _setVault(candy, address(vaultLimits), false);

        _deposit(alice, usdc, 300e6);
        _deposit(bob, usdc, 600e6);
        _deposit(candy, usdc, 900e6);

        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        _mint(address(usdc), candy, 1200e6);
        _approve(candy, address(usdc), address(size), 1200e6);

        vm.prank(candy);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626OpenZeppelin.ERC4626ExceededMaxDeposit.selector, address(borrowTokenVault), 1200e6, 1000e6
            )
        );
        size.deposit(DepositParams({token: address(usdc), amount: 1200e6, to: candy}));

        LimitsERC4626(address(vaultLimits)).setLimits(100e6, 100e6, 100e6, 100e6);

        assertEq(borrowTokenVault.totalSupply(), 1800e6);

        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        vm.expectRevert(
            abi.encodeWithSelector(IAdapter.InsufficientAssets.selector, address(vaultLimits), 100e6, 200e6)
        );
        vm.prank(bob);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 200e6,
                tenor: 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );
    }

    function test_Vaults_fee_on_entry_exit_vault() public {
        _setVaultAdapter(vaultFeeOnEntryExit, "ERC4626Adapter");
        _setVault(alice, address(vaultFeeOnEntryExit), false);

        Vars memory _before = _state();

        uint256 amount = 1000e6;
        _deposit(alice, usdc, amount);

        Vars memory _after = _state();

        assertEq(
            _after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + amount * uint256(1e4) / uint256(1.1e4)
        );

        _setVault(alice, address(0), false);
    }

    function test_Vaults_total_supply_across_multiple_vaults() public {
        _setVaultAdapter(vault2, "ERC4626Adapter");
        _setVault(alice, address(vault2), false);

        _deposit(alice, usdc, 200e6);
        _deposit(bob, usdc, 100e6);

        assertEq(size.data().borrowTokenVault.totalSupply(), 300e6);

        deal(address(usdc), address(liquidator), 10e6);
        vm.prank(liquidator);
        usdc.transfer(address(vault2), 10e6);

        address aToken = size.data().variablePool.getReserveData(address(usdc)).aTokenAddress;

        assertEqApprox(size.data().borrowTokenVault.totalSupply(), 310e6, 1);
        assertEq(usdc.balanceOf(address(vault2)) + usdc.balanceOf(aToken), 310e6);

        _withdraw(alice, usdc, 50e6);

        assertEqApprox(size.data().borrowTokenVault.totalSupply(), 260e6, 1);
        assertEq(usdc.balanceOf(address(vault2)) + usdc.balanceOf(aToken), 260e6);
    }

    function testFuzz_Vaults_changing_vault_does_not_leave_dust_shares(
        uint256 cash,
        uint256 tenor,
        uint256 apr,
        uint256 index,
        uint256 percent
    ) public {
        cash = bound(cash, 1, 100e6);
        index = bound(index, 1e27, 1.3e27);
        apr = bound(apr, 0.01e18, 0.1e18);
        tenor = bound(tenor, 1 days, 365 days);
        percent = bound(percent, 1e18, 2e18);

        _deposit(alice, usdc, cash);
        _deposit(bob, weth, 10e18);
        _deposit(candy, usdc, cash * percent / PERCENT);
        _deposit(liquidator, usdc, cash * 100);

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVaultAdapter(vault2, "ERC4626Adapter");
        _setVault(alice, address(vault), false);
        _setVault(bob, address(vault2), false);
        _setVault(candy, DEFAULT_VAULT, false);
        _setLiquidityIndex(index);

        _deposit(alice, usdc, cash);
        _deposit(bob, weth, 10e18);
        _deposit(candy, usdc, cash * percent / PERCENT);

        _setVault(alice, DEFAULT_VAULT, false);
        _setVault(bob, address(vault), false);
        _setVault(candy, address(vault2), false);
        _setLiquidityIndex(index * 1.1e18 / PERCENT);

        _deposit(alice, usdc, cash);
        _deposit(bob, weth, 10e18);
        _deposit(candy, usdc, cash * percent / PERCENT);

        _setVault(alice, DEFAULT_VAULT, false);
        _setVault(bob, address(vault), false);
        _setVault(candy, address(vault2), false);
        _setLiquidityIndex(index * 1.1e18 / PERCENT);

        _buyCreditLimit(alice, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr)));
        vm.prank(bob);
        try size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: cash,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        ) {
            uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(0)[0];

            _buyCreditLimit(
                candy, block.timestamp + tenor, YieldCurveHelper.pointCurve(tenor, int256(apr * percent / PERCENT))
            );

            _setLiquidityIndex(index * 1.1e18 / PERCENT);

            vm.prank(alice);
            try size.sellCreditMarket(
                SellCreditMarketParams({
                    lender: candy,
                    creditPositionId: creditPositionId,
                    amount: cash * percent / PERCENT,
                    tenor: tenor,
                    deadline: block.timestamp,
                    maxAPR: type(uint256).max,
                    exactAmountIn: true,
                    collectionId: RESERVED_ID,
                    rateProvider: address(0)
                })
            ) {} catch {}
        } catch {}
    }

    function test_Vaults_changing_vault_does_not_leave_dust_shares_1() public {
        testFuzz_Vaults_changing_vault_does_not_leave_dust_shares(9443, 4429, 2904, 8803, 1964);
    }

    function test_Vaults_changing_vault_does_not_leave_dust_shares_2() public {
        testFuzz_Vaults_changing_vault_does_not_leave_dust_shares(
            2406, 15025, 13859, 34341844514057354199208608556068539879975915923745875639004238636684834145893, 5314
        );
    }

    function test_Vaults_admin_can_DoS_user_operations_with_removeAdapter() public {
        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVault(alice, address(vault), false);

        _deposit(alice, usdc, 100e6);

        NonTransferrableRebasingTokenVault borrowTokenVault =
            NonTransferrableRebasingTokenVault(address(size.data().borrowTokenVault));
        vm.prank(address(this));
        borrowTokenVault.removeAdapter(bytes32("ERC4626Adapter"));

        vm.expectRevert();
        _withdraw(alice, usdc, type(uint256).max);

        vm.expectRevert();
        _setVault(alice, DEFAULT_VAULT, false);

        ERC4626Adapter newAdapter = new ERC4626Adapter(borrowTokenVault, usdc);

        vm.prank(address(this));
        borrowTokenVault.setAdapter(bytes32("ERC4626Adapter"), newAdapter);

        _withdraw(alice, usdc, type(uint256).max);
    }

    function test_Vaults_reentrancy_malicious_erc4626_same_market() public {
        ReentrancyMaliciousERC4626 maliciousVault = new ReentrancyMaliciousERC4626(address(usdc), size, alice);
        vm.label(address(maliciousVault), "ReentrancyMaliciousERC4626");

        _setVaultAdapter(address(maliciousVault), "ERC4626Adapter");
        _setAuthorization(alice, address(maliciousVault), Authorization.getActionsBitmap(Action.SET_VAULT));
        _setVault(alice, address(maliciousVault), false);
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;

        uint256 bobBalance = 1_000_000e6;
        uint256 aliceBalanceBefore = 1e6;

        _deposit(bob, usdc, bobBalance);
        assertEq(borrowTokenVault.vaultOf(bob), address(0), "bob vault is Aave");

        _mint(address(usdc), alice, aliceBalanceBefore);
        _approve(alice, address(usdc), address(size), aliceBalanceBefore);
        vm.prank(alice);
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        size.deposit(DepositParams({token: address(usdc), amount: aliceBalanceBefore, to: alice}));
        assertEq(
            borrowTokenVault.vaultOf(alice),
            address(maliciousVault),
            "alice vault is still ReentrancyMaliciousERC4626 (after nonReentrant addition)"
        );

        _withdraw(alice, usdc, bobBalance);
        assertEq(
            usdc.balanceOf(alice),
            aliceBalanceBefore,
            "alice did not drain the aave vault (after nonReentrant addition)"
        );
    }

    function test_Vaults_reentrancy_malicious_erc4626_multiple_markets() public {
        address borrowTokenVaultImplementation = address(new NonTransferrableRebasingTokenVault());
        NonTransferrableRebasingTokenVault borrowTokenVault = size.data().borrowTokenVault;
        UUPSUpgradeable(address(borrowTokenVault)).upgradeToAndCall(borrowTokenVaultImplementation, "");

        ReentrancyMaliciousERC4626 maliciousVault = new ReentrancyMaliciousERC4626(address(usdc), size2, alice);
        vm.label(address(maliciousVault), "ReentrancyMaliciousERC4626");

        _setVaultAdapter(address(maliciousVault), "ERC4626Adapter");
        _setAuthorization(alice, address(maliciousVault), Authorization.getActionsBitmap(Action.SET_VAULT));
        _setVault(alice, address(maliciousVault), false);

        uint256 bobBalance = 1_000_000e6;
        uint256 aliceBalanceBefore = 1e6;

        _deposit(bob, usdc, bobBalance);
        assertEq(borrowTokenVault.vaultOf(bob), address(0), "bob vault is Aave");

        _mint(address(usdc), alice, aliceBalanceBefore);
        _approve(alice, address(usdc), address(size), aliceBalanceBefore);
        vm.prank(alice);
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        size.deposit(DepositParams({token: address(usdc), amount: aliceBalanceBefore, to: alice}));
        assertEq(
            borrowTokenVault.vaultOf(alice),
            address(maliciousVault),
            "alice vault is still ReentrancyMaliciousERC4626 (after nonReentrant addition)"
        );

        _withdraw(alice, usdc, bobBalance);
        assertEq(
            usdc.balanceOf(alice),
            aliceBalanceBefore,
            "alice did not drain the aave vault (after nonReentrant addition)"
        );
    }

    function testFuzz_Vaults_setVault_should_not_allow_dust_shares(uint256 amount, uint256 mint) public {
        amount = bound(amount, 1, 10);
        mint = bound(mint, 0, 1_000_000e6);
        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVaultAdapter(vault3, "ERC4626Adapter");

        _setVault(alice, address(vault3), false);

        _deposit(alice, usdc, 1);

        _mint(address(usdc), address(vault3), mint);

        vm.assume(
            size.data().borrowTokenVault.balanceOf(alice) == 0 && size.data().borrowTokenVault.sharesOf(alice) > 0
        );

        vm.prank(alice);
        try size.setVault(SetVaultParams({vault: DEFAULT_VAULT, forfeitOldShares: false})) {}
        catch (bytes memory err) {
            assertTrue(
                isRevertReasonEqual(err, "ZERO_ASSETS"), "Tried to withdraw 1 share but it would result in 0 assets"
            );
        }
    }

    function test_Vaults_setVault_should_not_allow_dust_shares_concrete() public {
        testFuzz_Vaults_setVault_should_not_allow_dust_shares(3, 0);
    }

    function testFuzz_Vaults_setVault_should_not_DoS(
        address vaultFrom,
        address vaultTo,
        uint256 depositAmountFrom,
        uint256 depositAmountTo,
        uint256 mintFrom,
        uint256 mintTo
    ) public {
        depositAmountFrom = bound(depositAmountFrom, 0, 1e6);
        depositAmountTo = bound(depositAmountTo, 0, 1e6);
        mintFrom = bound(mintFrom, 0, 1_000_000e6);
        mintTo = bound(mintTo, 0, 1_000_000e6);
        address[] memory vaults = new address[](7);
        vaults[0] = address(vault);
        vaults[1] = address(vault2);
        vaults[2] = address(vault3);
        vaults[3] = address(DEFAULT_VAULT);
        vaults[4] = address(vaultFeeOnTransfer);
        vaults[5] = address(vaultFeeOnEntryExit);
        vaults[6] = address(vaultLimits);
        vaultFrom = vaults[uint256(uint160(vaultFrom)) % 7];
        vaultTo = vaults[uint256(uint160(vaultTo)) % 7];

        if (vaultFrom != address(0)) {
            _setVaultAdapter(vaultFrom, "ERC4626Adapter");
        }
        if (vaultTo != address(0)) {
            _setVaultAdapter(vaultTo, "ERC4626Adapter");
        }

        _setVault(alice, vaultFrom, false);

        if (depositAmountFrom > 0) {
            _deposit(alice, usdc, depositAmountFrom);
        }

        if (depositAmountTo > 0) {
            _setVault(bob, vaultTo, false);
            _deposit(bob, usdc, depositAmountTo);
        }

        _mint(address(usdc), address(vaultFrom), mintFrom);
        _mint(address(usdc), address(vaultTo), mintTo);

        vm.prank(alice);
        try size.setVault(SetVaultParams({vault: vaultTo, forfeitOldShares: false})) {}
        catch (bytes memory err) {
            bytes4[] memory errors = new bytes4[](2);
            errors[0] = IERC20Errors.ERC20InsufficientBalance.selector; // vault fee on transfer
            errors[1] = ERC4626OpenZeppelin.ERC4626ExceededMaxDeposit.selector; // vault limits
            bool found;
            for (uint256 i = 0; i < errors.length; i++) {
                if (bytes4(err) == errors[i]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                assertTrue(
                    err.length == 0 /* division by zero in `deposit` */ || isRevertReasonEqual(err, "ZERO_ASSETS") /* fullWithdraw does not return assets */
                        || isRevertReasonEqual(err, "ZERO_SHARES") /* deposit does not return shares */
                );
            }
        }
    }

    function test_Vaults_setVault_should_not_DoS_concrete_1() public {
        testFuzz_Vaults_setVault_should_not_DoS(
            0x7ADd2bc80b34C4f684acA34c32409Bb7d8B3EBAD,
            0x4710C436783aC52eAA285B379216F654E37bAc45,
            33465868994540527940485561327186911778221521359,
            1,
            168391758410948097870768843475662773,
            0
        );
    }

    function test_Vaults_setVault_should_not_DoS_concrete_2() public {
        testFuzz_Vaults_setVault_should_not_DoS(
            0xa8FDE076BbC5A5C1DdB21257830A3FEdBa83D5e6,
            0xA2A4691b231eB6fE12cA192d2af9378552384eC7,
            10926135349232105725494302465053164484692030030486046,
            0,
            36514846448020034121777649385718671084564959388979485374443577881365864745,
            1
        );
    }

    function test_Vaults_multicall_deposit_buyCreditMarket_can_revert_due_to_balanceOf_round_down() public {
        _deposit(bob, weth, 100e18);
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        address v = address(vaultFeeOnEntryExit);

        _setVaultAdapter(v, "ERC4626Adapter");
        _setVault(alice, v, false);

        _mint(address(usdc), v, 1);

        uint256 amount = 17957679;
        uint256 tenor = 365 days;

        _mint(address(usdc), alice, amount);
        _approve(alice, address(usdc), address(size), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: amount, to: alice}));
        data[1] = abi.encodeCall(
            size.buyCreditMarket,
            BuyCreditMarketParams({
                borrower: bob,
                creditPositionId: RESERVED_ID,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true,
                collectionId: RESERVED_ID,
                rateProvider: address(0)
            })
        );

        vm.prank(alice);
        try size.multicall(data) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), ERC4626OpenZeppelin.ERC4626ExceededMaxWithdraw.selector);
        }
    }
}
