// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ERC4626} from "@solady/src/tokens/ERC4626.sol";
import {MockERC4626} from "@solady/test/utils/mocks/MockERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {ControlledAsyncDeposit} from "@ERC-7540-Reference/src/ControlledAsyncDeposit.sol";
import {ControlledAsyncRedeem} from "@ERC-7540-Reference/src/ControlledAsyncRedeem.sol";
import {FullyAsyncVault} from "@ERC-7540-Reference/src/FullyAsyncVault.sol";
import {FeeOnTransferERC4626} from "@test/mocks/vaults/FeeOnTransferERC4626.sol";
import {MaliciousERC4626} from "@test/mocks/vaults/MaliciousERC4626.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

contract VaultsTest is BaseTest {
    function test_vaults_borrower_vault_lender_aave() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultWhitelisted(vault, true);
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_vaults_borrower_aave_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultWhitelisted(vault, true);
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_vaults_borrower_vault_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultWhitelisted(vault, true);
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_vaults_borrower_aave_lender_changes_vault_2_times_after_repay() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setVaultWhitelisted(vault, true);
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

    function test_vaults_lender_vault_low_liquidity() public {
        _setVaultWhitelisted(vault2, true);
        _setUserConfiguration(alice, address(vault2), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        // vault loses liquidity
        deal(address(usdc), address(vault2), 99e6);

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        vm.expectRevert(abi.encodeWithSelector(ERC4626.WithdrawMoreThanMax.selector));
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

    function test_vaults_malicious_vault() public {
        _setVaultWhitelisted(vaultMalicious, true);
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

    function test_vaults_fee_on_transfer_vault() public {
        _updateConfig("swapFeeAPR", 0);

        _setVaultWhitelisted(vaultFeeOnTransfer, true);
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

    function test_vaults_vault_with_wrong_underlying() public {
        _setVaultWhitelisted(vaultInvalidUnderlying, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_VAULT.selector, address(vaultInvalidUnderlying)));
        _setUserConfiguration(alice, address(vaultInvalidUnderlying), 1.5e18, false, false, new uint256[](0));
    }

    function test_vaults_non_erc4626_contract() public {
        _setVaultWhitelisted(vaultNonERC4626, true);
        vm.expectRevert();
        _setUserConfiguration(alice, address(vaultNonERC4626), 1.5e18, false, false, new uint256[](0));
    }

    function test_vaults_erc7540_fully_async_contract() public {
        // fully async ERC7540 vaults revert on deposit/withdraw

        _setVaultWhitelisted(vaultERC7540FullyAsync, true);
        _setUserConfiguration(alice, address(vaultERC7540FullyAsync), 1.5e18, false, false, new uint256[](0));

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);
        vm.prank(alice);
        vm.expectRevert();
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));
    }

    function test_vaults_erc7540_controlled_async_deposit_contract() public {
        // controlled async deposit ERC7540 vaults revert on deposit

        _setVaultWhitelisted(vaultERC7540ControlledAsyncDeposit, true);
        _setUserConfiguration(
            alice, address(vaultERC7540ControlledAsyncDeposit), 1.5e18, false, false, new uint256[](0)
        );

        _mint(address(usdc), alice, 200e6);
        _approve(alice, address(usdc), address(size), 200e6);
        vm.prank(alice);
        vm.expectRevert();
        size.deposit(DepositParams({token: address(usdc), amount: 200e6, to: alice}));
    }

    function test_vaults_erc7540_controlled_async_redeem_contract() public {
        // controlled async redeem ERC7540 vaults revert on withdraw

        _updateConfig("swapFeeAPR", 0);

        _setVaultWhitelisted(vaultERC7540ControlledAsyncRedeem, true);
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

    function test_vaults_total_supply_across_multiple_vaults() public {
        _setVaultWhitelisted(vault2, true);
        _setUserConfiguration(alice, address(vault2), 1.5e18, false, false, new uint256[](0));

        _deposit(alice, usdc, 200e6);
        _deposit(bob, usdc, 100e6);

        assertEq(size.data().borrowTokenVault.totalSupply(), 300e6);

        deal(address(usdc), address(vault2), 210e6);

        address aToken = size.data().variablePool.getReserveData(address(usdc)).aTokenAddress;

        assertEq(size.data().borrowTokenVault.totalSupply(), 300e6);
        assertEq(usdc.balanceOf(address(vault2)) + usdc.balanceOf(aToken), 310e6);

        _withdraw(alice, usdc, 50e6);

        assertEq(size.data().borrowTokenVault.totalSupply(), 250e6);
        assertEq(usdc.balanceOf(address(vault2)) + usdc.balanceOf(aToken), 260e6);
    }
}
