// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockERC4626} from "@solady/../test/utils/mocks/MockERC4626.sol";
import {ERC4626} from "@solady/tokens/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {FeeOnTransferERC4626} from "@test/mocks/vaults/FeeOnTransferERC4626.sol";
import {MaliciousERC4626} from "@test/mocks/vaults/MaliciousERC4626.sol";

import {FullyAsyncVault} from "@ERC-7540-Reference/FullyAsyncVault.sol";

contract UserVaultsTest is BaseTest {
    IERC4626 vault2;
    IERC4626 vaultMalicious;
    IERC4626 vaultFeeOnTransfer;
    IERC4626 vaultNonERC4626;
    IERC4626 vaultERC7540;
    IERC4626 vaultInvalidUnderlying;
    uint256 public constant TIMELOCK = 24 hours;

    function setUp() public override {
        super.setUp();
        vault2 = IERC4626(address(new MockERC4626(address(usdc), "Vault2", "VAULT2", true, 0)));
        vaultMalicious = IERC4626(address(new MaliciousERC4626(usdc, "VaultMalicious", "VAULTMALICIOUS")));
        vaultFeeOnTransfer =
            IERC4626(address(new FeeOnTransferERC4626(usdc, "VaultFeeOnTransfer", "VAULTFEEONTXFER", 0.1e18)));
        vaultNonERC4626 = IERC4626(address(new ERC20Mock()));
        vaultERC7540 = IERC4626(address(new FullyAsyncVault(ERC20(address(usdc)), "VaultERC7540", "VAULTERC7540")));
        vaultInvalidUnderlying = IERC4626(
            address(new MockERC4626(address(weth), "VaultInvalidUnderlying", "VAULTINVALIDUNDERLYING", true, 0))
        );
    }

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

    function test_UserVaults_borrower_vault_lender_vault() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setUserVaultWhitelistEnabled(false);
        _setUserConfiguration(alice, address(vault), 1.5e18, false, false, new uint256[](0));
        _setUserConfiguration(bob, address(vault), 1.5e18, false, false, new uint256[](0));

        _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);
    }

    function test_UserVaults_borrower_aave_lender_changes_vault_2_times_after_repay() public {
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 100e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));

        uint256 amount = 100e6;
        uint256 tenor = 365 days;

        _setUserVaultWhitelistEnabled(false);
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

    function test_UserVaults_lender_vault_low_liquidity() public {
        _setUserVaultWhitelistEnabled(false);
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

    function test_UserVaults_malicious_vault() public {
        _setUserVaultWhitelistEnabled(false);
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

    function test_UserVaults_fee_on_transfer_vault() public {}
    function test_UserVaults_vault_with_wrong_underlying() public {}
    function test_UserVaults_non_erc4626_contract() public {}
    function test_UserVaults_erc7540_contract() public {}
    function test_UserVaults_dust_shares_when_changing_vaults() public {}
    function test_UserVaults_total_supply_across_multiple_vaults() public {}
}
