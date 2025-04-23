// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract UserVaultsTest is BaseTest {
    function test_UserVaults_borrower_vault_lender_aave() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setUserVaultWhitelistEnabled(false);
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_UserVaults_borrower_aave_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setUserVaultWhitelistEnabled(false);
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_UserVaults_borrower_vault_lender_vault() public {}
    function test_UserVaults_borrower_aave_lender_changes_vault_2_times() public {}
    function test_UserVaults_vault_low_liquidity() public {}
    function test_UserVaults_malicious_vault() public {}
    function test_UserVaults_fee_on_transfer_vault() public {}
    function test_UserVaults_default_vault_used_when_none_specified() public {}
    function test_UserVaults_cannot_choose_vault_with_wrong_underlying() public {}
    function test_UserVaults_cannot_choose_non_erc4626_contract() public {}
    function test_UserVaults_erc7540_contract() public {}
    function test_UserVaults_cannot_choose_vault_that_fails_on_deposit_or_withdraw() public {}
    function test_UserVaults_change_vault_after_lending_but_before_repay() public {}
    function test_UserVaults_multiple_vault_changes_between_repay_and_claim() public {}
    function test_UserVaults_vault_deposit_rejected_when_global_cap_reached() public {}
    function test_UserVaults_can_still_repay_when_cap_reached() public {}
    function test_UserVaults_prevent_ghost_shares_or_fake_balance_transfer() public {}
    function test_UserVaults_share_balance_drops_correctly_on_withdraw() public {}
    function test_UserVaults_total_supply_correct_across_multiple_vaults() public {}
    function test_UserVaults_migration_from_sausdc() public {}
    function test_UserVaults_sausdc_user_can_claim_after_migration() public {}
    function test_UserVaults_vault_with_zero_shares() public {}
    function test_UserVaults_deposit_with_fee_on_transfer_token_has_correct_shares() public {}
    function test_UserVaults_withdrawal_to_zero_address_reverts() public {}
}
