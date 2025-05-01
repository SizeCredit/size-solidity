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
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {Adapter} from "@src/market/token/libraries/AdapterLibrary.sol";

import {
    CopyLimitOrder,
    CopyLimitOrdersOnBehalfOfParams,
    CopyLimitOrdersParams
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
    SizeMock size1;
    SizeMock size2;
    PriceFeedMock priceFeed2;
    IERC20Metadata collateral2;
    CopyLimitOrder fullCopy =
        CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});

    function setUp() public override {
        super.setUp();
        collateral2 = IERC20Metadata(address(new ERC20Mock()));
        priceFeed2 = new PriceFeedMock(address(this));
        priceFeed2.setPrice(1e18);

        ISize market = sizeFactory.getMarket(0);
        InitializeFeeConfigParams memory feeConfigParams = market.feeConfig();

        InitializeRiskConfigParams memory riskConfigParams = market.riskConfig();
        riskConfigParams.crOpening = 1.12e18;
        riskConfigParams.crLiquidation = 1.09e18;

        InitializeOracleParams memory oracleParams = market.oracle();
        oracleParams.priceFeed = address(priceFeed2);

        DataView memory dataView = market.data();
        InitializeDataParams memory dataParams = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(collateral2),
            underlyingBorrowToken: address(dataView.underlyingBorrowToken),
            variablePool: address(dataView.variablePool),
            borrowTokenVault: address(dataView.borrowTokenVault),
            sizeFactory: address(sizeFactory)
        });
        size2 = SizeMock(address(sizeFactory.createMarket(feeConfigParams, riskConfigParams, oracleParams, dataParams)));
        size1 = size;

        vm.label(address(size1), "Size1");
        vm.label(address(size2), "Size2");
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
                                exactAmountIn: false
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
                                exactAmountIn: false
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

    function test_CallMarket_can_copy_limit_orders_from_multiple_markets() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 500e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        size = size2;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.04e18));
        size = size1;

        bytes[] memory datas = new bytes[](4);
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
                            params: CopyLimitOrdersParams({
                                copyAddress: alice,
                                copyLoanOffer: fullCopy,
                                copyBorrowOffer: fullCopy
                            }),
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
                            params: CopyLimitOrdersParams({
                                copyAddress: alice,
                                copyLoanOffer: fullCopy,
                                copyBorrowOffer: fullCopy
                            }),
                            onBehalfOf: bob
                        })
                    )
                )
            )
        );
        datas[3] =
            abi.encodeCall(ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.nullActionsBitmap()));

        vm.startPrank(bob);
        sizeFactory.multicall(datas);

        assertEq(size1.getLoanOfferAPR(bob, 365 days), 0.03e18);
        assertEq(size2.getLoanOfferAPR(bob, 365 days), 0.04e18);
    }

    function test_CallMarket_user_can_execute_ideal_flow() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 500e6);

        size = size1;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        size = size2;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.04e18));

        _setVaultAdapter(vault2, Adapter.ERC4626);

        uint256 depositAmount = 100e6;

        _mint(address(usdc), candy, depositAmount);

        Action[] memory actions = new Action[](3);
        actions[0] = Action.SET_USER_CONFIGURATION;
        actions[1] = Action.DEPOSIT;
        actions[2] = Action.COPY_LIMIT_ORDERS;

        bytes[] memory datas = new bytes[](6);
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
        datas[3] = abi.encodeCall(
            ISizeFactoryV1_8.callMarket,
            (
                size1,
                abi.encodeCall(
                    ISizeV1_7.copyLimitOrdersOnBehalfOf,
                    (
                        CopyLimitOrdersOnBehalfOfParams({
                            params: CopyLimitOrdersParams({
                                copyAddress: alice,
                                copyLoanOffer: fullCopy,
                                copyBorrowOffer: fullCopy
                            }),
                            onBehalfOf: candy
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
                    ISizeV1_7.copyLimitOrdersOnBehalfOf,
                    (
                        CopyLimitOrdersOnBehalfOfParams({
                            params: CopyLimitOrdersParams({
                                copyAddress: alice,
                                copyLoanOffer: fullCopy,
                                copyBorrowOffer: fullCopy
                            }),
                            onBehalfOf: candy
                        })
                    )
                )
            )
        );
        datas[5] =
            abi.encodeCall(ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.nullActionsBitmap()));

        vm.prank(candy);
        usdc.approve(address(size1), depositAmount);
        vm.prank(candy);
        sizeFactory.multicall(datas);

        assertEq(_state().candy.borrowTokenBalance, depositAmount);
        assertEq(size1.getLoanOfferAPR(candy, 365 days), 0.03e18);
        assertEq(size2.getLoanOfferAPR(candy, 365 days), 0.04e18);
    }
}
