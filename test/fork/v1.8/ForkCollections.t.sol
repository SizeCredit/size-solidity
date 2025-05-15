// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Contract, Networks} from "@script/Networks.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";
import {console} from "forge-std/console.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626Morpho} from "@test/fork/v1.8/interfaces/IERC4626Morpho.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {ProposeSafeTxUpgradeToV1_8Script} from "@script/ProposeSafeTxUpgradeToV1_8.s.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams,
    SellCreditMarketWithCollectionParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

contract ForkCollectionsTest is ForkTest, Networks {
    ProposeSafeTxUpgradeToV1_8Script script;

    address[] users;
    ISize[] collectionMarkets;
    address curator;
    address rateProvider;

    uint256[][] usersPreviousLoanAPRsPerCollectionMarket;

    uint256 tenor = 30 days;
    uint256 collectionId = 0;

    function setUp() public override(ForkTest) {
        vm.createSelectFork("base_archive");
        // 2025-05-12 16h50 UTC
        vm.rollFork(30139655);

        sizeFactory = importSizeFactory("base-production-size-factory");
        size = SizeMock(address(sizeFactory.getMarket(0)));
        usdc = USDC(address(size.data().underlyingBorrowToken));
        weth = WETH(payable(address(size.data().underlyingCollateralToken)));
        variablePool = size.data().variablePool;
        owner = Networks.contracts[block.chainid][Contract.SIZE_GOVERNANCE];

        script = new ProposeSafeTxUpgradeToV1_8Script();

        users = new address[](2);
        users[0] = 0x87CDad83a779D785A729a91dBb9FE0DB8be14b3b;
        users[1] = 0x000000f840D8A851718d7DC470bFf1ed09F69107;

        collectionMarkets = script.getCollectionMarkets(sizeFactory);
        curator = makeAddr("curator");
        rateProvider = 0x39EB0e1039732d8d2380B682Bc00Ad07b864F176;

        _getPreviousState();

        _upgradeToV1_8();

        _labels();
    }

    function _getPreviousState() internal {
        usersPreviousLoanAPRsPerCollectionMarket = new uint256[][](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            usersPreviousLoanAPRsPerCollectionMarket[i] = new uint256[](collectionMarkets.length);
            for (uint256 j = 0; j < collectionMarkets.length; j++) {
                ISize collectionMarket = collectionMarkets[j];
                (bool success, bytes memory data) = address(collectionMarket).call(
                    abi.encodeWithSignature("getLoanOfferAPR(address,uint256)", users[i], tenor)
                );
                assertEq(success, true);
                usersPreviousLoanAPRsPerCollectionMarket[i][j] = abi.decode(data, (uint256));
            }
        }
    }

    function _upgradeToV1_8() internal {
        (address[] memory targets, bytes[] memory datas) =
            script.getTargetsAndDatas(sizeFactory, users, curator, rateProvider, collectionMarkets);

        for (uint256 i = 0; i < targets.length; i++) {
            vm.prank(owner);
            (bool success,) = targets[i].call(datas[i]);
            assertTrue(success);
        }
    }

    function testFork_ForkCollections_users_subscribing_to_existing_RP_now_have_1_collection() public view {
        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < collectionMarkets.length; j++) {
                ISize collectionMarket = collectionMarkets[j];
                uint256 loanAPR = collectionMarket.getLoanOfferAPR(users[i], collectionId, rateProvider, tenor);
                assertEq(loanAPR, usersPreviousLoanAPRsPerCollectionMarket[i][j]);
            }
        }
    }

    function testFork_ForkCollections_market_orders_on_users_subscribing_to_existing_RP_now_fail_if_no_collection_is_passed(
    ) public {
        _deposit(alice, weth, 100e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, users[0]));
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: users[0],
                        creditPositionId: RESERVED_ID,
                        amount: 10e6,
                        tenor: tenor,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp,
                        exactAmountIn: false
                    }),
                    collectionId: RESERVED_ID,
                    rateProvider: address(0)
                }),
                onBehalfOf: alice,
                recipient: alice
            })
        );

        vm.prank(alice);
        size.sellCreditMarketOnBehalfOf(
            SellCreditMarketOnBehalfOfParams({
                withCollectionParams: SellCreditMarketWithCollectionParams({
                    params: SellCreditMarketParams({
                        lender: users[0],
                        creditPositionId: RESERVED_ID,
                        amount: 10e6,
                        tenor: tenor,
                        maxAPR: type(uint256).max,
                        deadline: block.timestamp,
                        exactAmountIn: false
                    }),
                    collectionId: collectionId,
                    rateProvider: rateProvider
                }),
                onBehalfOf: alice,
                recipient: alice
            })
        );
    }
}
