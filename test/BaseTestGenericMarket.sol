// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract BaseTestGenericMarket is BaseTest {
    function setUp() public virtual override {
        revert Errors.NOT_SUPPORTED();
    }

    function setUp_USDT_cbBTC() public {
        setupLocalGenericMarket(address(this), feeRecipient, 1e18, 60576e18, 6, 8, false, false);

        _labels();
        vm.label(address(collateralToken), "CTK (USDT)");
        vm.label(address(borrowToken), "BTK (cbBTC)");
        vm.label(address(size.data().collateralToken), "szCTK (szUSDT)");
        vm.label(address(size.data().borrowAToken), "szaBTK (szacbBTC)");
        vm.label(address(size.data().debtToken), "szDebtBTK (szDebtcbBTC)");
    }

    function setUp_cbBTC_USDC() public {
        setupLocalGenericMarket(address(this), feeRecipient, 60576e18, 0.9999e18, 8, 6, false, false);

        _labels();
        vm.label(address(collateralToken), "CTK (cbBTC)");
        vm.label(address(borrowToken), "BTK (USDC)");
        vm.label(address(size.data().collateralToken), "szCTK (szcbBTC)");
        vm.label(address(size.data().borrowAToken), "szaBTK (szaUSDC)");
        vm.label(address(size.data().debtToken), "szDebtBTK (szDebtUSDC)");
    }

    function setUp_wstETH_ETH() public {
        setupLocalGenericMarket(address(this), feeRecipient, 3127e18, 2653e18, 18, 18, false, true);

        _labels();
        vm.label(address(collateralToken), "CTK (wstETH)");
        vm.label(address(borrowToken), "BTK (ETH)");
        vm.label(address(size.data().collateralToken), "szCTK (szwstETH)");
        vm.label(address(size.data().borrowAToken), "szaBTK (szaETH)");
        vm.label(address(size.data().debtToken), "szDebtBTK (szDebtETH)");
    }

    function setUp_sUSDe_USDC() public {
        setupLocalGenericMarket(address(this), feeRecipient, 1.1e18, 0.9999e18, 18, 6, false, false);

        _labels();
        vm.label(address(collateralToken), "CTK (sUSDe)");
        vm.label(address(borrowToken), "BTK (USDC)");
        vm.label(address(size.data().collateralToken), "szCTK (szsUSDe)");
        vm.label(address(size.data().borrowAToken), "szaBTK (szaUSDC)");
        vm.label(address(size.data().debtToken), "szDebtBTK (szDebtUSDC)");
    }
}
