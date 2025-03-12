// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@crytic/properties/contracts/util/Hevm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {NetworkConfiguration} from "@script/Networks.sol";
import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/market/token/NonTransferrableScaledTokenV1_5.sol";

abstract contract Deploy {
    address internal implementation;
    ERC1967Proxy internal proxy;
    SizeMock internal size;
    IPriceFeed internal priceFeed;
    WETH internal weth;
    USDC internal usdc;
    IPool internal variablePool;
    InitializeFeeConfigParams internal f;
    InitializeRiskConfigParams internal r;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;

    IERC20Metadata internal collateralToken;
    IERC20Metadata internal borrowToken;

    SizeFactory internal sizeFactory;

    bool internal shouldDeploySizeFactory = true;

    function setupLocal(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(weth), WadRayMath.RAY);
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);

        if (shouldDeploySizeFactory) {
            sizeFactory = SizeFactory(
                address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (owner))))
            );
        }

        address borrowATokenV1_5Implementation = address(new NonTransferrableScaledTokenV1_5());

        hevm.prank(owner);
        sizeFactory.setNonTransferrableScaledTokenV1_5Implementation(borrowATokenV1_5Implementation);

        hevm.prank(owner);
        NonTransferrableScaledTokenV1_5 borrowATokenV1_5 = sizeFactory.createBorrowATokenV1_5(variablePool, usdc);

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: 5e6,
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowAToken: 5e6,
            borrowATokenCap: 1_000_000e6,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool), // Aave v3
            borrowATokenV1_5: address(borrowATokenV1_5),
            sizeFactory: address(sizeFactory)
        });

        implementation = address(new SizeMock());
        hevm.prank(owner);
        sizeFactory.setSizeImplementation(implementation);

        hevm.prank(owner);
        proxy = ERC1967Proxy(payable(address(sizeFactory.createMarket(f, r, o, d))));
        size = SizeMock(payable(proxy));

        hevm.prank(owner);
        PriceFeedMock(address(priceFeed)).setPrice(1337e18);
    }

    function setupLocalGenericMarket(
        address owner,
        address feeRecipient,
        uint256 collateralTokenPriceUSD,
        uint256 borrowTokenPriceUSD,
        uint8 collateralTokenDecimals,
        uint8 borrowTokenDecimals,
        bool collateralTokenIsWETH,
        bool borrowTokenIsWETH
    ) internal {
        priceFeed = new PriceFeedMock(owner);
        uint256 price = Math.mulDivDown(collateralTokenPriceUSD, 10 ** priceFeed.decimals(), borrowTokenPriceUSD);

        weth = new WETH();
        collateralToken = IERC20Metadata(address(new MockERC20("CollateralToken", "CTK", collateralTokenDecimals)));
        borrowToken = IERC20Metadata(address(new MockERC20("BorrowToken", "BTK", borrowTokenDecimals)));
        if (collateralTokenIsWETH) {
            collateralToken = IERC20Metadata(address(weth));
        }
        if (borrowTokenIsWETH) {
            borrowToken = IERC20Metadata(address(weth));
        }

        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(borrowToken), 1.234567e27);

        if (shouldDeploySizeFactory) {
            sizeFactory = SizeFactory(
                address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (owner))))
            );
        }

        address borrowATokenV1_5Implementation = address(new NonTransferrableScaledTokenV1_5());

        hevm.prank(owner);
        sizeFactory.setNonTransferrableScaledTokenV1_5Implementation(borrowATokenV1_5Implementation);

        hevm.prank(owner);
        NonTransferrableScaledTokenV1_5 borrowATokenV1_5 = sizeFactory.createBorrowATokenV1_5(variablePool, borrowToken);

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: Math.mulDivDown(
                5 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
            ),
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowAToken: Math.mulDivDown(
                10 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
            ),
            borrowATokenCap: Math.mulDivDown(
                1_000_000 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
            ),
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(collateralToken),
            underlyingBorrowToken: address(borrowToken),
            variablePool: address(variablePool),
            borrowATokenV1_5: address(borrowATokenV1_5),
            sizeFactory: address(sizeFactory)
        });

        implementation = address(new SizeMock());
        hevm.prank(owner);
        sizeFactory.setSizeImplementation(implementation);

        hevm.prank(owner);
        proxy = ERC1967Proxy(payable(address(sizeFactory.createMarket(f, r, o, d))));
        size = SizeMock(payable(proxy));

        hevm.prank(owner);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function setupFork(address _size, address _priceFeed, address _variablePool, address _weth, address _usdc)
        internal
    {
        size = SizeMock(_size);
        priceFeed = IPriceFeed(_priceFeed);
        variablePool = IPool(_variablePool);
        weth = WETH(payable(_weth));
        usdc = USDC(_usdc);
    }
}
