// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/market/libraries/Errors.sol";

import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";

import {UserCopyLimitOrders} from "@src/market/SizeStorage.sol";
import {OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";

import {
    BuyCreditMarketOnBehalfOfParams,
    BuyCreditMarketParams,
    BuyCreditMarketWithCollectionParams
} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {CopyLimitOrdersParams} from "@src/market/libraries/actions/CopyLimitOrders.sol";
import {
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams,
    SellCreditMarketWithCollectionParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {DataView} from "@src/market/SizeViewData.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";

contract CollectionsTest is BaseTest {
    CopyLimitOrderConfig private nullCopy;
    CopyLimitOrderConfig private noCopy =
        CopyLimitOrderConfig({minTenor: 0, maxTenor: 0, minAPR: 0, maxAPR: 0, offsetAPR: type(int256).max});
    CopyLimitOrderConfig private fullCopy = CopyLimitOrderConfig({
        minTenor: 0,
        maxTenor: type(uint256).max,
        minAPR: 0,
        maxAPR: type(uint256).max,
        offsetAPR: 0
    });

    SizeMock size1;
    SizeMock size2;
    PriceFeedMock priceFeed2;
    IERC20Metadata collateral2;

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

    function test_Collections_subscribeToCollection_check_APR() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 borrowOfferAPR = size.getUserDefinedBorrowOfferAPR(bob, 30 days);
        assertEq(borrowOfferAPR, 0.05e18);

        uint256 loanOfferAPR = size.getUserDefinedLoanOfferAPR(bob, 60 days);
        assertEq(loanOfferAPR, 0.08e18);

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), borrowOfferAPR);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), loanOfferAPR);
    }

    function test_Collections_subscribeToCollection_copy_only_loan_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, fullCopy, noCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 30 days, 0, 0));
        size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.12e18));
        assertEq(size.getUserDefinedBorrowOfferAPR(alice, 30 days), 0.12e18);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);
    }

    function test_Collections_copyLimitOrders_copy_only_borrow_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, noCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 60 days, 0, 0));
        size.getLoanOfferAPR(alice, collectionId, bob, 60 days);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.07e18));
        assertEq(size.getUserDefinedLoanOfferAPR(alice, 60 days), 0.07e18);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
    }

    function test_Collections_unsubscribeFromCollections_reset_copy() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, fullCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _unsubscribeFromCollection(alice, collectionId);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICollectionsManagerView.InvalidCollectionMarketRateProvider.selector,
                collectionId,
                address(size),
                address(bob)
            )
        );
        size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICollectionsManagerView.InvalidCollectionMarketRateProvider.selector,
                collectionId,
                address(size),
                address(bob)
            )
        );
        size.getLoanOfferAPR(alice, collectionId, bob, 60 days);
    }

    function test_Collections_copyLimitOrders_tenor_boundaries() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.02e18), uint256(15 days), uint256(0.07e18))
        );

        CopyLimitOrderConfig memory copyLoanOfferConfig =
            CopyLimitOrderConfig({minTenor: 4 days, maxTenor: 6 days, minAPR: 0.05e18, maxAPR: 0.1e18, offsetAPR: 0});

        CopyLimitOrderConfig memory copyBorrowOfferConfig =
            CopyLimitOrderConfig({minTenor: 2 days, maxTenor: 10 days, minAPR: 0.01e18, maxAPR: 0.03e18, offsetAPR: 0});

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, copyLoanOfferConfig, copyBorrowOfferConfig);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getUserDefinedLoanOfferAPR(bob, 3 days), 0.03e18);
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 3 days, 4 days, 6 days));
        size.getLoanOfferAPR(alice, collectionId, bob, 3 days);

        assertEq(size.getUserDefinedBorrowOfferAPR(bob, 15 days), 0.07e18);
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 15 days, 2 days, 10 days));
        size.getBorrowOfferAPR(alice, collectionId, bob, 15 days);
    }

    function test_Collections_copyLimitOrders_apr_boundaries() public {
        uint256 maxDueDate = block.timestamp + 365 days;
        uint256[] memory marketRateMultipliers = new uint256[](4);
        uint256[] memory tenors = new uint256[](4);
        tenors[0] = 3 days;
        tenors[1] = 4 days;
        tenors[2] = 6 days;
        tenors[3] = 7 days;
        int256[] memory aprs = new int256[](4);
        aprs[0] = 0.03e18;
        aprs[1] = 0.04e18;
        aprs[2] = 0.12e18;
        aprs[3] = 0.15e18;

        _buyCreditLimit(
            bob, maxDueDate, YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.02e18), uint256(15 days), uint256(0.3e18))
        );

        CopyLimitOrderConfig memory copyLoanOfferConfig =
            CopyLimitOrderConfig({minTenor: 4 days, maxTenor: 6 days, minAPR: 0.1e18, maxAPR: 0.11e18, offsetAPR: 0});

        CopyLimitOrderConfig memory copyBorrowOfferConfig =
            CopyLimitOrderConfig({minTenor: 2 days, maxTenor: 10 days, minAPR: 0.05e18, maxAPR: 0.12e18, offsetAPR: 0});

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, copyLoanOfferConfig, copyBorrowOfferConfig);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getUserDefinedLoanOfferAPR(bob, 4 days), 0.04e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 4 days), 0.1e18);

        assertEq(size.getUserDefinedLoanOfferAPR(bob, 6 days), 0.12e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 6 days), 0.11e18);

        assertEq(size.getUserDefinedBorrowOfferAPR(bob, 2 days), 0.04e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 2 days), 0.05e18);

        assertEq(size.getUserDefinedBorrowOfferAPR(bob, 10 days), 0.2e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 10 days), 0.12e18);
    }

    function test_Collections_copyLimitOrders_loan_offer_scenario() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(
                uint256(1 days), uint256(0.02e18), uint256(10 days), uint256(0.2e18), uint256(30 days), uint256(0.25e18)
            )
        );

        CopyLimitOrderConfig memory copyLoanOfferConfig = CopyLimitOrderConfig({
            minTenor: 3 days,
            maxTenor: 7 days,
            minAPR: 0.1e18,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, copyLoanOfferConfig, noCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 3 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 5 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 7 days), 0.14e18);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 1 days, 3 days, 7 days));
        size.getLoanOfferAPR(alice, collectionId, bob, 1 days);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 10 days, 3 days, 7 days));
        size.getLoanOfferAPR(alice, collectionId, bob, 10 days);
    }

    function test_Collections_copyLimitOrders_borrow_offer_scenario() public {
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(
                uint256(1 days), uint256(0.02e18), uint256(10 days), uint256(0.2e18), uint256(30 days), uint256(0.25e18)
            )
        );

        CopyLimitOrderConfig memory copyBorrowOfferConfig =
            CopyLimitOrderConfig({minTenor: 3 days, maxTenor: 15 days, minAPR: 0, maxAPR: 0.1e18, offsetAPR: 0});

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, noCopy, copyBorrowOfferConfig);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 3 days), 0.06e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 5 days), 0.1e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 10 days), 0.1e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 15 days), 0.1e18);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 1 days, 3 days, 15 days));
        size.getBorrowOfferAPR(alice, collectionId, bob, 1 days);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 20 days, 3 days, 15 days));
        size.getBorrowOfferAPR(alice, collectionId, bob, 20 days);
    }

    function test_Collections_subscribeToCollection_market_order_chooses_rate_provider() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, fullCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.1e18));
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.15e18));

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.06e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.09e18));

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.09e18);
    }

    function test_Collections_copyLimitOrders_deletes_single_copy() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, fullCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.1e18));

        _copyLimitOrders(alice, noCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getUserDefinedLoanOfferAPR(alice, 60 days), 0.1e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.06e18));

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18);
        assertEq(size.getUserDefinedLoanOfferAPR(alice, 60 days), 0.1e18);
    }

    function test_Collections_copyLimitOrders_with_offset() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(30 days), uint256(0.05e18), uint256(60 days), uint256(0.08e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(30 days), uint256(0.07e18), uint256(60 days), uint256(0.18e18))
        );

        CopyLimitOrderConfig memory copyLoanOfferConfig = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0.1e18,
            maxAPR: type(uint256).max,
            offsetAPR: 0.03e18
        });

        CopyLimitOrderConfig memory copyBorrowOfferConfig = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: 0.12e18,
            offsetAPR: -0.01e18
        });

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, copyLoanOfferConfig, copyBorrowOfferConfig);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.11e18);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 60 days), 0.12e18);
    }

    function test_Collections_subscribeToCollection_can_leave_inverted_curves_with_offsetAPR() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.03e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        CopyLimitOrderConfig memory loanCopy = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: -0.01e18
        });

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, loanCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.03e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.04e18);

        assertTrue(
            size.getLoanOfferAPR(alice, collectionId, bob, 30 days)
                > size.getBorrowOfferAPR(alice, collectionId, bob, 30 days)
        );

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.04e18));

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.04e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.04e18);

        assertTrue(
            !(
                size.getLoanOfferAPR(alice, collectionId, bob, 30 days)
                    > size.getBorrowOfferAPR(alice, collectionId, bob, 30 days)
            )
        );
    }

    function test_Collections_subscribeToCollection_leave_inverted_curves_but_market_orders_revert() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.03e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        CopyLimitOrderConfig memory loanCopy = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: -0.01e18
        });

        _deposit(alice, weth, 1 ether);
        _deposit(alice, usdc, 3000e6);

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, loanCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.03e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.04e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.04e18));

        _deposit(candy, usdc, 2000e6);
        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 30 days, 0.04e18, 0.04e18));
        vm.prank(candy);
        size.buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({
                withCollectionParams: BuyCreditMarketWithCollectionParams({
                    params: BuyCreditMarketParams({
                        borrower: alice,
                        creditPositionId: RESERVED_ID,
                        amount: 500e6,
                        tenor: 30 days,
                        minAPR: 0,
                        deadline: block.timestamp + 365 days,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 30 days, 0.04e18, 0.04e18));
        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: alice,
                        creditPositionId: RESERVED_ID,
                        amount: 500e6,
                        tenor: 30 days,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp + 365 days,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );
    }

    function test_Collections_subscribeToCollection_rateProvider_removes_inverted_curve_then_market_order_succeeds()
        public
    {
        _deposit(alice, usdc, 200e6);
        _deposit(candy, weth, 100e18);

        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.15e18), uint256(15 days), uint256(0.17e18))
        );

        CopyLimitOrderConfig memory borrowCopy =
            CopyLimitOrderConfig({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: 0.1e18, offsetAPR: 0});

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, fullCopy, borrowCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 5 days, 0.075e18, 0.1e18));
        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: alice,
                        creditPositionId: RESERVED_ID,
                        amount: 10e6,
                        tenor: 5 days,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );

        YieldCurve memory nullCurve;
        _sellCreditLimit(bob, 0, nullCurve);

        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: alice,
                        creditPositionId: RESERVED_ID,
                        amount: 10e6,
                        tenor: 5 days,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );
    }

    function test_Collections_subscribeToCollection_rateProvider_updates_offer_then_user_market_order_reverts()
        public
    {
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 200e6);
        _deposit(candy, weth, 100e18);

        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.15e18), uint256(15 days), uint256(0.17e18))
        );

        CopyLimitOrderConfig memory borrowCopy =
            CopyLimitOrderConfig({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: 0.1e18, offsetAPR: 0});

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _copyLimitOrders(alice, fullCopy, borrowCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 5 days, 0.075e18, 0.1e18));
        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: alice,
                        creditPositionId: RESERVED_ID,
                        amount: 10e6,
                        tenor: 5 days,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );

        _sellCreditLimit(
            bob,
            block.timestamp + 4 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.15e18), uint256(15 days), uint256(0.17e18))
        );

        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: alice,
                        creditPositionId: RESERVED_ID,
                        amount: 10e6,
                        tenor: 5 days,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );

        uint256 debtPositionId = 0;
        uint256 futureValue = 10e6 + uint256(10e6 * 0.075e18 * 5 days) / 365 days / 1e18 + 1;
        assertEq(size.getDebtPosition(debtPositionId).futureValue, futureValue);
    }

    function test_Collections_isCopyingCollectionMarketRateProvider() public {
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size1);
        _addRateProviderToCollectionMarket(james, collectionId, size1, bob);

        _subscribeToCollection(alice, collectionId);

        assertEq(collectionsManager.isCopyingCollectionMarketRateProvider(alice, collectionId + 1, size1, bob), false);
        assertEq(collectionsManager.isCopyingCollectionMarketRateProvider(alice, collectionId, size2, bob), false);
        assertEq(collectionsManager.isCopyingCollectionMarketRateProvider(alice, collectionId, size1, bob), true);

        vm.expectRevert(abi.encodeWithSelector(CollectionsManagerBase.InvalidCollectionId.selector, collectionId + 1));
        collectionsManager.getCollectionMarketCopyLoanOfferConfig(collectionId + 1, size1);

        vm.expectRevert(
            abi.encodeWithSelector(CollectionsManagerBase.MarketNotInCollection.selector, collectionId, size2)
        );
        collectionsManager.getCollectionMarketCopyLoanOfferConfig(collectionId, size2);

        CopyLimitOrderConfig memory config =
            collectionsManager.getCollectionMarketCopyLoanOfferConfig(collectionId, size1);
        assertEq(config.minTenor, 0);
        assertEq(config.maxTenor, type(uint256).max);
        assertEq(config.minAPR, 0);
        assertEq(config.maxAPR, type(uint256).max);
        assertEq(config.offsetAPR, 0);

        config = collectionsManager.getCollectionMarketCopyBorrowOfferConfig(collectionId, size1);
        assertEq(config.minTenor, 0);
        assertEq(config.maxTenor, type(uint256).max);
        assertEq(config.minAPR, 0);
        assertEq(config.maxAPR, type(uint256).max);
        assertEq(config.offsetAPR, 0);
    }

    function test_Collections_subscribeToCollections_can_leave_inverted_curves_O_n_m_check() public {}
}
