// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {PERCENT} from "@src/market/libraries/Math.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ERC4626 as ERC4626OpenZeppelin} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {ERC20 as ERC20Solady} from "@solady/src/tokens/ERC20.sol";
import {ERC4626 as ERC4626Solady} from "@solady/src/tokens/ERC4626.sol";
import {MockERC4626} from "@solady/test/utils/mocks/MockERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {ControlledAsyncDeposit} from "@ERC-7540-Reference/src/ControlledAsyncDeposit.sol";
import {ControlledAsyncRedeem} from "@ERC-7540-Reference/src/ControlledAsyncRedeem.sol";
import {FullyAsyncVault} from "@ERC-7540-Reference/src/FullyAsyncVault.sol";

import {FeeOnEntryExitERC4626} from "@test/mocks/vaults/FeeOnEntryExitERC4626.sol";
import {FeeOnTransferERC4626} from "@test/mocks/vaults/FeeOnTransferERC4626.sol";
import {LimitsERC4626} from "@test/mocks/vaults/LimitsERC4626.sol";
import {MaliciousERC4626} from "@test/mocks/vaults/MaliciousERC4626.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

contract VaultsTest is BaseTest {
    function test_Vaults_borrower_vault_lender_aave() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_Vaults_borrower_aave_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_Vaults_borrower_vault_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_Vaults_borrower_aave_lender_changes_vault_2_times_after_repay() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _deposit(bob, usdc, 100e6);
        _repay(bob, debtPositionId, bob);

        _setUserConfiguration(alice, address(0), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(alice, address(vault2), 1.5e18, false, false, new uint256[](0));

        _claim(alice, creditPositionId);
    }

    function test_Vaults_lender_vault_low_liquidity() public {
        _setVaultAdapter(vault, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));

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
                exactAmountIn: false
            })
        );

        uint256 balanceBefore = usdc.balanceOf(alice);

        // user can still withdraw from vault with low liquidity
        _withdraw(alice, address(usdc), 100e6);

        assertEq(usdc.balanceOf(alice), balanceBefore + 99e6, "user should have received only available liquidity");
    }

    function test_Vaults_malicious_vault() public {
        _setVaultAdapter(vaultMalicious, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vaultMalicious), 1.5e18, false, false, new uint256[](0));

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
                exactAmountIn: false
            })
        );
    }

    function test_Vaults_fee_on_transfer_vault() public {
        _updateConfig("swapFeeAPR", 0);

        _setVaultAdapter(vaultFeeOnTransfer, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vaultFeeOnTransfer), 1.5e18, false, false, new uint256[](0));

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

        _setUserConfiguration(alice, address(vaultInvalidUnderlying), 1.5e18, false, false, new uint256[](0));
    }

    function test_Vaults_non_erc4626_contract() public {
        NonTransferrableRebasingTokenVault borrowTokenVault =
            NonTransferrableRebasingTokenVault(address(size.data().borrowTokenVault));
        vm.prank(address(this));
        vm.expectRevert();
        borrowTokenVault.setVaultAdapter(address(vaultNonERC4626), "ERC4626Adapter");

        _setUserConfiguration(alice, address(vaultNonERC4626), 1.5e18, false, false, new uint256[](0));
    }

    function test_Vaults_erc7540_fully_async_contract() public {
        // fully async ERC7540 vaults revert on deposit/withdraw

        _setVaultAdapter(vaultERC7540FullyAsync, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vaultERC7540FullyAsync), 1.5e18, false, false, new uint256[](0));

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);
        vm.prank(alice);
        vm.expectRevert();
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));
    }

    function test_Vaults_erc7540_controlled_async_deposit_contract() public {
        // controlled async deposit ERC7540 vaults revert on deposit

        _setVaultAdapter(vaultERC7540ControlledAsyncDeposit, "ERC4626Adapter");
        _setUserConfiguration(
            alice, address(vaultERC7540ControlledAsyncDeposit), 1.5e18, false, false, new uint256[](0)
        );

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
        _setUserConfiguration(alice, address(vaultERC7540ControlledAsyncRedeem), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vaultERC7540ControlledAsyncRedeem), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(
            size.feeConfig().feeRecipient,
            address(vaultERC7540ControlledAsyncRedeem),
            1.5e18,
            false,
            false,
            new uint256[](0)
        );

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

        // buyCreditMarket can be used to "exit" from vaults that revert on withdraw
        _buyCreditMarket(alice, bob, RESERVED_ID, amount, tenor, true);

        _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance - amount);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance + amount);

        vm.expectRevert();
        _withdraw(bob, address(usdc), 100e6);
    }

    function test_Vaults_limits_vault() public {
        _setVaultAdapter(vaultLimits, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vaultLimits), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vaultLimits), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(candy, address(vaultLimits), 1.5e18, false, false, new uint256[](0));

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
    }

    function test_Vaults_fee_on_entry_exit_vault() public {
        _setVaultAdapter(vaultFeeOnEntryExit, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vaultFeeOnEntryExit), 1.5e18, false, false, new uint256[](0));

        Vars memory _before = _state();

        _deposit(alice, usdc, 1000e6);

        Vars memory _after = _state();

        assertEq(
            _after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + 1000e6 * uint256(1e4) / uint256(1.1e4)
        );
    }

    function test_Vaults_total_supply_across_multiple_vaults() public {
        _setVaultAdapter(vault2, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault2), 1.5e18, false, false, new uint256[](0));

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
        string memory err = "Changing vault leaves dust shares";
        cash = bound(cash, 1, 100e6);
        index = bound(index, 1e27, 1.3e27);
        apr = bound(apr, 0.01e18, 0.1e18);
        tenor = bound(tenor, 1 days, 365 days);
        percent = bound(percent, 1e18, 2e18);

        _deposit(alice, usdc, cash);
        _deposit(bob, weth, 10e18);
        _deposit(candy, usdc, cash * percent / PERCENT);
        _deposit(liquidator, usdc, cash * 100);
        assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);

        _setVaultAdapter(vault, "ERC4626Adapter");
        _setVaultAdapter(vault2, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault2), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(candy, address(DEFAULT_VAULT), 1.5e18, false, false, new uint256[](0));
        _setLiquidityIndex(index);
        assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);

        _deposit(alice, usdc, cash);
        _deposit(bob, weth, 10e18);
        _deposit(candy, usdc, cash * percent / PERCENT);
        assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);

        _setUserConfiguration(alice, address(DEFAULT_VAULT), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(candy, address(vault2), 1.5e18, false, false, new uint256[](0));
        _setLiquidityIndex(index * 1.1e18 / PERCENT);
        assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);

        _deposit(alice, usdc, cash);
        _deposit(bob, weth, 10e18);
        _deposit(candy, usdc, cash * percent / PERCENT);
        assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);

        _setUserConfiguration(alice, address(DEFAULT_VAULT), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(candy, address(vault2), 1.5e18, false, false, new uint256[](0));
        _setLiquidityIndex(index * 1.1e18 / PERCENT);
        assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);

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
                exactAmountIn: false
            })
        ) {
            assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);
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
                    exactAmountIn: true
                })
            ) {
                assertTrue(!_isDustShares([alice, bob, candy, liquidator]), err);
            } catch {}
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

    function _isDustShares(address[4] memory) internal pure returns (bool) {
        // TODO implement this
        return false;
    }

    function test_Vaults_admin_can_DoS_user_operations_with_removeAdapter() public {
        _setVaultAdapter(vault, "ERC4626Adapter");
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);

        NonTransferrableRebasingTokenVault borrowTokenVault =
            NonTransferrableRebasingTokenVault(address(size.data().borrowTokenVault));
        vm.prank(address(this));
        borrowTokenVault.removeAdapter(bytes32("ERC4626Adapter"));

        vm.expectRevert();
        _withdraw(alice, usdc, type(uint256).max);

        vm.expectRevert();
        _setUserConfiguration(alice, address(DEFAULT_VAULT), 1.5e18, false, false, new uint256[](0));

        ERC4626Adapter newAdapter = new ERC4626Adapter(borrowTokenVault, usdc);

        vm.prank(address(this));
        borrowTokenVault.setAdapter(bytes32("ERC4626Adapter"), newAdapter);

        _withdraw(alice, usdc, type(uint256).max);
    }
}
