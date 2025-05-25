// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";
import {ISizeFactoryV1_8} from "@src/factory/interfaces/ISizeFactoryV1_8.sol";
import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {DataView} from "@src/market/SizeViewData.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
import {
    CopyLimitOrdersOnBehalfOfParams, CopyLimitOrdersParams
} from "@src/market/libraries/actions/CopyLimitOrders.sol";
import {DepositOnBehalfOfParams, DepositParams} from "@src/market/libraries/actions/Deposit.sol";

import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";
import {
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {
    SetUserConfigurationOnBehalfOfParams,
    SetUserConfigurationParams
} from "@src/market/libraries/actions/SetUserConfiguration.sol";
import {WithdrawOnBehalfOfParams, WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";

contract CallMarketTest is BaseTest {
    CopyLimitOrderConfig fullCopy = CopyLimitOrderConfig({
        minTenor: 0,
        maxTenor: type(uint256).max,
        minAPR: 0,
        maxAPR: type(uint256).max,
        offsetAPR: 0
    });

    function setUp() public override {
        super.setUp();
        _deploySizeMarket2();
    }

    function test_CallMarket_can_borrow_from_multiple_markets() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 500e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        size = size2;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.04e18));
        size = size1;

        uint256 usdcBalanceBefore = usdc.balanceOf(bob);

        uint256 usdcAmount = 100e6;
        uint256 tenor = 365 days;

        uint256 wethAmount = 300e18;
        uint256 collateral2Amount = 400e18;

        _mint(address(weth), bob, wethAmount);
        _mint(address(collateral2), bob, collateral2Amount);
        _approve(bob, address(weth), address(size1), wethAmount);
        _approve(bob, address(collateral2), address(size2), collateral2Amount);

        Action[] memory actions = new Action[](3);
        actions[0] = Action.DEPOSIT;
        actions[1] = Action.SELL_CREDIT_MARKET;
        actions[2] = Action.WITHDRAW;

        bytes[] memory datas = new bytes[](7);
        datas[0] = abi.encodeCall(
            ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.getActionsBitmap(actions))
        );
        datas[1] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.depositOnBehalfOf,
                    (
                        DepositOnBehalfOfParams({
                            params: DepositParams({token: address(weth), amount: wethAmount, to: bob}),
                            onBehalfOf: bob
                        })
                    )
                )
            )
        );
        datas[2] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.sellCreditMarketOnBehalfOf,
                    (
                        SellCreditMarketOnBehalfOfParams({
                            params: SellCreditMarketParams({
                                lender: alice,
                                creditPositionId: RESERVED_ID,
                                amount: usdcAmount,
                                tenor: tenor,
                                deadline: block.timestamp,
                                maxAPR: type(uint256).max,
                                exactAmountIn: false,
                                collectionId: RESERVED_ID,
                                rateProvider: address(0)
                            }),
                            onBehalfOf: bob,
                            recipient: bob
                        })
                    )
                )
            )
        );
        datas[3] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size2,
                abi.encodeCall(
                    ISizeV1_7.depositOnBehalfOf,
                    (
                        DepositOnBehalfOfParams({
                            params: DepositParams({token: address(collateral2), amount: collateral2Amount, to: bob}),
                            onBehalfOf: bob
                        })
                    )
                )
            )
        );
        datas[4] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size2,
                abi.encodeCall(
                    ISizeV1_7.sellCreditMarketOnBehalfOf,
                    (
                        SellCreditMarketOnBehalfOfParams({
                            params: SellCreditMarketParams({
                                lender: alice,
                                creditPositionId: RESERVED_ID,
                                amount: usdcAmount,
                                tenor: tenor,
                                deadline: block.timestamp,
                                maxAPR: type(uint256).max,
                                exactAmountIn: false,
                                collectionId: RESERVED_ID,
                                rateProvider: address(0)
                            }),
                            onBehalfOf: bob,
                            recipient: bob
                        })
                    )
                )
            )
        );
        datas[5] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.withdrawOnBehalfOf,
                    (
                        WithdrawOnBehalfOfParams({
                            params: WithdrawParams({token: address(usdc), amount: type(uint256).max, to: bob}),
                            onBehalfOf: bob
                        })
                    )
                )
            )
        );
        datas[6] =
            abi.encodeCall(ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.nullActionsBitmap()));

        vm.startPrank(bob);
        sizeFactory.multicall(datas);

        assertEq(usdc.balanceOf(bob), usdcBalanceBefore + usdcAmount * 2);
    }

    function test_CallMarket_cannot_call_invalid_market() public {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MARKET.selector, address(alice)));
        sizeFactory.callMarket(
            ISize(address(alice)),
            abi.encodeCall(ISize.withdraw, (WithdrawParams({token: address(usdc), amount: 100e6, to: bob})))
        );
    }

    function test_CallMarket_can_copy_limit_orders_from_multiple_markets() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 500e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        size = size2;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.04e18));
        size = size1;

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size1);
        _addMarketToCollection(james, collectionId, size2);
        _addRateProviderToCollectionMarket(james, collectionId, size1, alice);
        _addRateProviderToCollectionMarket(james, collectionId, size2, alice);

        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;

        bytes[] memory datas = new bytes[](5);
        datas[0] = abi.encodeCall(
            ISizeFactoryV1_7.setAuthorization,
            (address(sizeFactory), Authorization.getActionsBitmap(Action.COPY_LIMIT_ORDERS))
        );
        datas[1] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.copyLimitOrdersOnBehalfOf,
                    (
                        CopyLimitOrdersOnBehalfOfParams({
                            params: CopyLimitOrdersParams({copyLoanOfferConfig: fullCopy, copyBorrowOfferConfig: fullCopy}),
                            onBehalfOf: bob
                        })
                    )
                )
            )
        );
        datas[2] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size2,
                abi.encodeCall(
                    ISizeV1_7.copyLimitOrdersOnBehalfOf,
                    (
                        CopyLimitOrdersOnBehalfOfParams({
                            params: CopyLimitOrdersParams({copyLoanOfferConfig: fullCopy, copyBorrowOfferConfig: fullCopy}),
                            onBehalfOf: bob
                        })
                    )
                )
            )
        );
        datas[3] =
            abi.encodeCall(ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.nullActionsBitmap()));
        datas[4] = abi.encodeCall(ISizeFactoryV1_8.subscribeToCollections, (collectionIds));

        vm.startPrank(bob);
        sizeFactory.multicall(datas);

        assertEq(size1.getLoanOfferAPR(bob, collectionId, alice, 365 days), 0.03e18);
        assertEq(size2.getLoanOfferAPR(bob, collectionId, alice, 365 days), 0.04e18);
    }

    function test_CallMarket_user_can_execute_ideal_flow() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 500e6);

        size = size1;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        size = size2;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.04e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size1);
        _addMarketToCollection(james, collectionId, size2);
        _addRateProviderToCollectionMarket(james, collectionId, size1, alice);
        _addRateProviderToCollectionMarket(james, collectionId, size2, alice);

        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;

        _setVaultAdapter(vault2, "ERC4626Adapter");

        uint256 depositAmount = 100e6;

        _mint(address(usdc), candy, depositAmount);

        Action[] memory actions = new Action[](3);
        actions[0] = Action.SET_USER_CONFIGURATION;
        actions[1] = Action.DEPOSIT;
        actions[2] = Action.COPY_LIMIT_ORDERS;

        bytes[] memory datas = new bytes[](5);
        datas[0] = abi.encodeCall(
            ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.getActionsBitmap(actions))
        );
        datas[1] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.setUserConfigurationOnBehalfOf,
                    (
                        SetUserConfigurationOnBehalfOfParams({
                            params: SetUserConfigurationParams({
                                vault: address(vault2),
                                openingLimitBorrowCR: 1.5e18,
                                allCreditPositionsForSaleDisabled: false,
                                creditPositionIdsForSale: false,
                                creditPositionIds: new uint256[](0)
                            }),
                            onBehalfOf: candy
                        })
                    )
                )
            )
        );
        datas[2] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.depositOnBehalfOf,
                    (
                        DepositOnBehalfOfParams({
                            params: DepositParams({token: address(usdc), amount: depositAmount, to: candy}),
                            onBehalfOf: candy
                        })
                    )
                )
            )
        );
        datas[3] = abi.encodeCall(ISizeFactoryV1_8.subscribeToCollections, (collectionIds));
        datas[4] =
            abi.encodeCall(ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.nullActionsBitmap()));

        vm.prank(candy);
        usdc.approve(address(size1), depositAmount);
        vm.prank(candy);
        sizeFactory.multicall(datas);

        assertEq(_state().candy.borrowTokenBalance, depositAmount);
        assertEq(size1.getLoanOfferAPR(candy, collectionId, alice, 365 days), 0.03e18);
        assertEq(size2.getLoanOfferAPR(candy, collectionId, alice, 365 days), 0.04e18);
    }
}
