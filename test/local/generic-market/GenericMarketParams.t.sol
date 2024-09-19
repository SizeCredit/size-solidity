// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {BaseTestGenericMarket} from "@test/BaseTestGenericMarket.sol";

contract GenericMarketParamsTest is BaseTestGenericMarket {
    function setUp() public virtual override {
        this.setUp_USDT_cbBTC();
    }

    function test_GenericMarketParams_check_token_decimals() public {
        assertEq(size.data().collateralToken.decimals(), 6);
        assertEq(size.data().borrowAToken.decimals(), 8);
        assertEq(size.data().debtToken.decimals(), 8);
    }

    function test_GenericMarketParams_check_price() public {
        assertEq(size.debtTokenAmountToCollateralTokenAmount(1e8), 60576e6);
    }

    function test_GenericMarketParams_deposit_eth_reverts() public {
        vm.deal(alice, 1 ether);

        assertEq(address(alice).balance, 1 ether);
        assertEq(_state().alice.borrowATokenBalance, 0);
        assertEq(_state().alice.collateralTokenBalance, 0);

        vm.startPrank(alice);

        vm.expectRevert();
        size.deposit{value: 1 ether}(DepositParams({token: address(weth), amount: 1 ether, to: alice}));
    }
}
