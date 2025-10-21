// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/market/libraries/Errors.sol";

import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";

import {UserCopyLimitOrderConfigs} from "@src/market/SizeStorage.sol";
import {OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";

import {
    BuyCreditMarketOnBehalfOfParams, BuyCreditMarketParams
} from "@src/market/libraries/actions/BuyCreditMarket.sol";

import {
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {SetCopyLimitOrderConfigsParams} from "@src/market/libraries/actions/SetCopyLimitOrderConfigs.sol";
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

    function setUp() public override {
        super.setUp();
        _deploySizeMarket2();
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

        _setCopyLimitOrderConfigs(alice, fullCopy, noCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 30 days, 0, 0));
        size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.12e18));
        assertEq(size.getUserDefinedBorrowOfferAPR(alice, 30 days), 0.12e18);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);
    }

    function test_Collections_setCopyLimitOrderConfigs_copy_only_borrow_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _setCopyLimitOrderConfigs(alice, noCopy, fullCopy);
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

        _setCopyLimitOrderConfigs(alice, fullCopy, fullCopy);
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

    function test_Collections_setCopyLimitOrderConfigs_tenor_boundaries() public {
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

        _setCopyLimitOrderConfigs(alice, copyLoanOfferConfig, copyBorrowOfferConfig);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getUserDefinedLoanOfferAPR(bob, 3 days), 0.03e18);
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 3 days, 4 days, 6 days));
        size.getLoanOfferAPR(alice, collectionId, bob, 3 days);

        assertEq(size.getUserDefinedBorrowOfferAPR(bob, 15 days), 0.07e18);
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 15 days, 2 days, 10 days));
        size.getBorrowOfferAPR(alice, collectionId, bob, 15 days);
    }

    function test_Collections_setCopyLimitOrderConfigs_apr_boundaries() public {
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

        _setCopyLimitOrderConfigs(alice, copyLoanOfferConfig, copyBorrowOfferConfig);
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

    function test_Collections_setCopyLimitOrderConfigs_loan_offer_scenario() public {
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

        _setCopyLimitOrderConfigs(alice, copyLoanOfferConfig, noCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 3 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 5 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 7 days), 0.14e18);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 1 days, 3 days, 7 days));
        size.getLoanOfferAPR(alice, collectionId, bob, 1 days);

        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 10 days, 3 days, 7 days));
        size.getLoanOfferAPR(alice, collectionId, bob, 10 days);
    }

    function test_Collections_setCopyLimitOrderConfigs_borrow_offer_scenario() public {
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

        _setCopyLimitOrderConfigs(alice, noCopy, copyBorrowOfferConfig);
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

        _setCopyLimitOrderConfigs(alice, fullCopy, fullCopy);
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

    function test_Collections_setCopyLimitOrderConfigs_deletes_single_copy() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _setCopyLimitOrderConfigs(alice, fullCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.1e18));

        _setCopyLimitOrderConfigs(alice, noCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getUserDefinedLoanOfferAPR(alice, 60 days), 0.1e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.06e18));

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18);
        assertEq(size.getUserDefinedLoanOfferAPR(alice, 60 days), 0.1e18);
    }

    function test_Collections_setCopyLimitOrderConfigs_with_offset() public {
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

        _setCopyLimitOrderConfigs(alice, copyLoanOfferConfig, copyBorrowOfferConfig);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.11e18);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 60 days), 0.12e18);
    }

    function test_Collections_subscribeToCollection_can_leave_inverted_curves_with_offsetAPR() public {
        _deposit(alice, usdc, 1000e6);
        _deposit(candy, weth, 100e18);

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

        _setCopyLimitOrderConfigs(alice, loanCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.03e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.04e18);

        assertTrue(
            size.getLoanOfferAPR(alice, collectionId, bob, 30 days)
                > size.getBorrowOfferAPR(alice, collectionId, bob, 30 days)
        );

        vm.prank(candy);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 50e6,
                tenor: 30 days,
                maxAPR: type(uint256).max,
                deadline: block.timestamp + 365 days,
                exactAmountIn: false,
                collectionId: collectionId,
                rateProvider: bob
            })
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

        vm.prank(candy);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVERTED_CURVES.selector, alice, 30 days));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 50e6,
                tenor: 30 days,
                maxAPR: type(uint256).max,
                deadline: block.timestamp + 365 days,
                exactAmountIn: false,
                collectionId: collectionId,
                rateProvider: bob
            })
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

        _setCopyLimitOrderConfigs(alice, loanCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.03e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.04e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.04e18));

        _deposit(candy, usdc, 2000e6);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVERTED_CURVES.selector, alice, 30 days));
        vm.prank(candy);
        size.buyCreditMarketOnBehalfOf(
            BuyCreditMarketOnBehalfOfParams({
                params: BuyCreditMarketParams({
                    borrower: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 500e6,
                    tenor: 30 days,
                    minAPR: 0,
                    deadline: block.timestamp + 365 days,
                    exactAmountIn: false,
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVERTED_CURVES.selector, alice, 30 days));
        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                params: SellCreditMarketParams({
                    lender: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 500e6,
                    tenor: 30 days,
                    maxAPR: type(uint256).max,
                    deadline: block.timestamp + 365 days,
                    exactAmountIn: false,
                    collectionId: collectionId,
                    rateProvider: bob
                }),
                onBehalfOf: candy,
                recipient: candy
            })
        );
    }

    function test_Collections_subscribeToCollection_inverted_curves_many_markets() public {
        size = size2;
        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.12e18));

        size = size1;
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

        _setCopyLimitOrderConfigs(alice, loanCopy, fullCopy);
        _subscribeToCollection(alice, collectionId);

        uint256 borrowAPRMarket1 = size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);
        uint256 loanAPRMarket1 = size.getLoanOfferAPR(alice, collectionId, bob, 30 days);
        uint256 borrowAPRMarket2 = size2.getBorrowOfferAPR(alice, RESERVED_ID, address(0), 30 days);

        assertEq(borrowAPRMarket1, 0.03e18);
        assertEq(loanAPRMarket1, 0.04e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.04e18));

        borrowAPRMarket1 = size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);
        loanAPRMarket1 = size.getLoanOfferAPR(alice, collectionId, bob, 30 days);
        borrowAPRMarket2 = size2.getBorrowOfferAPR(alice, RESERVED_ID, address(0), 30 days);

        assertTrue(!collectionsManager.isBorrowAPRLowerThanLoanOfferAPRs(alice, borrowAPRMarket1, size, 30 days));

        assertTrue(
            collectionsManager.isBorrowAPRLowerThanLoanOfferAPRs(alice, borrowAPRMarket2, size2, 30 days),
            "On market 2, offers are OK since there is only one offer"
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

        _setCopyLimitOrderConfigs(alice, fullCopy, borrowCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVERTED_CURVES.selector, alice, 5 days));
        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                params: SellCreditMarketParams({
                    lender: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 10e6,
                    tenor: 5 days,
                    maxAPR: type(uint256).max,
                    deadline: block.timestamp,
                    exactAmountIn: false,
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
                params: SellCreditMarketParams({
                    lender: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 10e6,
                    tenor: 5 days,
                    maxAPR: type(uint256).max,
                    deadline: block.timestamp,
                    exactAmountIn: false,
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

        _setCopyLimitOrderConfigs(alice, fullCopy, borrowCopy);
        _subscribeToCollection(alice, collectionId);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVERTED_CURVES.selector, alice, 5 days));
        vm.prank(candy);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                params: SellCreditMarketParams({
                    lender: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 10e6,
                    tenor: 5 days,
                    maxAPR: type(uint256).max,
                    deadline: block.timestamp,
                    exactAmountIn: false,
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
                params: SellCreditMarketParams({
                    lender: alice,
                    creditPositionId: RESERVED_ID,
                    amount: 10e6,
                    tenor: 5 days,
                    maxAPR: type(uint256).max,
                    deadline: block.timestamp,
                    exactAmountIn: false,
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
    }

    function test_Collections_subscribeToCollections_can_leave_inverted_curves_O_n_m_check() public {}

    // ============ v1.8.1 Tests: Per-Collection Config ============

    function test_Collections_setUserCollectionCopyLimitOrderConfigs_basic() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // Verify default full copy after subscription
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        // Update per-collection config with restricted tenor
        CopyLimitOrderConfig memory restrictedLoanConfig = CopyLimitOrderConfig({
            minTenor: 50 days,
            maxTenor: 70 days,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, restrictedLoanConfig, fullCopy);

        // Should still work for borrow offer
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);

        // Should work for loan offer within bounds
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.08e18);

        // Should revert for loan offer outside bounds
        vm.expectRevert(
            abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 30 days, 50 days, 70 days)
        );
        size.getLoanOfferAPR(alice, collectionId, bob, 30 days);
    }

    function test_Collections_perMarket_precedence_over_perCollection() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(30 days), uint256(0.08e18), uint256(90 days), uint256(0.1e18))
        );

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        // Set per-collection config with restricted tenor
        CopyLimitOrderConfig memory collectionConfig = CopyLimitOrderConfig({
            minTenor: 50 days,
            maxTenor: 70 days,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        _subscribeToCollection(alice, collectionId);
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, collectionConfig, fullCopy);

        // Verify per-collection config is active (should fail because 30 days < 50 days minTenor)
        vm.expectRevert(
            abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 30 days, 50 days, 70 days)
        );
        size.getLoanOfferAPR(alice, collectionId, bob, 30 days);

        // Set per-market config with different tenor
        CopyLimitOrderConfig memory marketConfig = CopyLimitOrderConfig({
            minTenor: 20 days,
            maxTenor: 80 days,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        _setCopyLimitOrderConfigs(alice, marketConfig, fullCopy);

        // Per-market should take precedence - 30 days is now valid
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.08e18);

        // 90 days is outside per-market bounds (20-80 days) so should revert
        vm.expectRevert(
            abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 90 days, 20 days, 80 days)
        );
        size.getLoanOfferAPR(alice, collectionId, bob, 90 days);
    }

    function test_Collections_perCollection_config_with_offset() public {
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

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // Set per-collection config with offset
        CopyLimitOrderConfig memory loanConfigWithOffset = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0.02e18
        });
        CopyLimitOrderConfig memory borrowConfigWithOffset = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: -0.01e18
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, loanConfigWithOffset, borrowConfigWithOffset);

        // Verify offset is applied
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.07e18); // 0.05 + 0.02
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18); // 0.07 - 0.01
    }

    function test_Collections_perCollection_config_with_minMaxAPR() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(30 days), uint256(0.02e18), uint256(60 days), uint256(0.15e18))
        );

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // Set per-collection config with min/max APR
        CopyLimitOrderConfig memory loanConfig = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0.05e18,
            maxAPR: 0.1e18,
            offsetAPR: 0
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, loanConfig, noCopy);

        // APR below minAPR should be clamped
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.05e18); // clamped from 0.02

        // APR above maxAPR should be clamped
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 60 days), 0.1e18); // clamped from 0.15
    }

    function test_Collections_multiple_collections_different_configs() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(20 days), uint256(0.07e18), uint256(40 days), uint256(0.08e18))
        );

        _sellCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.06e18));
        _buyCreditLimit(
            candy,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(50 days), uint256(0.085e18), uint256(90 days), uint256(0.09e18))
        );

        // Create two collections with different rate providers
        uint256 collectionId1 = _createCollection(james);
        _addMarketToCollection(james, collectionId1, size);
        _addRateProviderToCollectionMarket(james, collectionId1, size, bob);

        uint256 collectionId2 = _createCollection(james);
        _addMarketToCollection(james, collectionId2, size);
        _addRateProviderToCollectionMarket(james, collectionId2, size, candy);

        _subscribeToCollection(alice, collectionId1);
        _subscribeToCollection(alice, collectionId2);

        // Set different configs for each collection
        CopyLimitOrderConfig memory config1 =
            CopyLimitOrderConfig({minTenor: 0, maxTenor: 40 days, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId1, config1, fullCopy);

        CopyLimitOrderConfig memory config2 = CopyLimitOrderConfig({
            minTenor: 50 days,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId2, config2, fullCopy);

        // Collection 1 should work for 30 days
        assertEq(size.getLoanOfferAPR(alice, collectionId1, bob, 30 days), 0.075e18);

        // Collection 1 should fail for 50 days (outside maxTenor of 40 days)
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 50 days, 0, 40 days));
        size.getLoanOfferAPR(alice, collectionId1, bob, 50 days);

        // Collection 2 should work for 60 days
        // APR for 60 days: 0.085 + (0.09 - 0.085) * (60 - 50) / (90 - 50) = 0.085 + 0.00125 = 0.08625
        assertApproxEqAbs(size.getLoanOfferAPR(alice, collectionId2, candy, 60 days), 0.08625e18, 1e15);

        // Collection 2 should fail for 30 days (outside minTenor of 50 days)
        vm.expectRevert(
            abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 30 days, 50 days, type(uint256).max)
        );
        size.getLoanOfferAPR(alice, collectionId2, candy, 30 days);
    }

    function test_Collections_unsubscribe_clears_perCollection_config() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // Set per-collection config
        CopyLimitOrderConfig memory restrictedConfig = CopyLimitOrderConfig({
            minTenor: 20 days,
            maxTenor: 40 days,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, noCopy, restrictedConfig);

        // Verify config is active
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);

        // Unsubscribe
        _unsubscribeFromCollection(alice, collectionId);

        // Should revert since alice is no longer subscribed
        vm.expectRevert(
            abi.encodeWithSelector(
                ICollectionsManagerView.InvalidCollectionMarketRateProvider.selector,
                collectionId,
                address(size),
                address(bob)
            )
        );
        size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);
    }

    function test_Collections_perCollection_config_market_order() public {
        _deposit(alice, usdc, 1000e6);
        _deposit(candy, weth, 100e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // Set per-collection config with offset to keep spread
        CopyLimitOrderConfig memory loanConfig = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0.01e18
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, loanConfig, fullCopy);

        // Verify APRs with collection config
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, collectionId, bob, 30 days), 0.09e18); // 0.08 + 0.01

        // Market order should succeed
        vm.prank(candy);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 50e6,
                tenor: 30 days,
                maxAPR: type(uint256).max,
                deadline: block.timestamp + 365 days,
                exactAmountIn: false,
                collectionId: collectionId,
                rateProvider: bob
            })
        );
    }

    function test_Collections_perCollection_config_cannot_set_for_invalid_collection() public {
        uint256 invalidCollectionId = 999;

        vm.expectRevert(
            abi.encodeWithSelector(CollectionsManagerBase.InvalidCollectionId.selector, invalidCollectionId)
        );
        _setUserCollectionCopyLimitOrderConfigs(alice, invalidCollectionId, fullCopy, fullCopy);
    }

    function test_Collections_perCollection_config_only_borrow_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // Set per-collection config with only borrow offer
        CopyLimitOrderConfig memory borrowConfig = CopyLimitOrderConfig({
            minTenor: 20 days,
            maxTenor: 40 days,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, noCopy, borrowConfig);

        // Borrow offer should work within bounds
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);

        // Borrow offer should fail outside bounds
        vm.expectRevert(
            abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 50 days, 20 days, 40 days)
        );
        size.getBorrowOfferAPR(alice, collectionId, bob, 50 days);

        // Loan offer should fail since it's set to noCopy
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 60 days, 0, 0));
        size.getLoanOfferAPR(alice, collectionId, bob, 60 days);
    }

    function test_Collections_perCollection_update_config_multiple_times() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        uint256 collectionId = _createCollection(james);
        _addMarketToCollection(james, collectionId, size);
        _addRateProviderToCollectionMarket(james, collectionId, size, bob);

        _subscribeToCollection(alice, collectionId);

        // First config
        CopyLimitOrderConfig memory config1 =
            CopyLimitOrderConfig({minTenor: 0, maxTenor: 40 days, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, noCopy, config1);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.05e18);

        // Update to second config
        CopyLimitOrderConfig memory config2 = CopyLimitOrderConfig({
            minTenor: 20 days,
            maxTenor: 50 days,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0.01e18
        });
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, noCopy, config2);
        assertEq(size.getBorrowOfferAPR(alice, collectionId, bob, 30 days), 0.06e18); // 0.05 + 0.01

        // Update to third config (null)
        _setUserCollectionCopyLimitOrderConfigs(alice, collectionId, noCopy, nullCopy);
        vm.expectRevert(abi.encodeWithSelector(ICollectionsManagerView.InvalidTenor.selector, 30 days, 0, 0));
        size.getBorrowOfferAPR(alice, collectionId, bob, 30 days);
    }
}
