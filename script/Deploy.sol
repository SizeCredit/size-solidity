// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {Math} from "@src/libraries/Math.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {PriceFeed} from "@src/oracle/PriceFeed.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/Size.sol";

import {NetworkConfiguration} from "@script/Networks.sol";
import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

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

    MockERC20 internal collateralToken;
    MockERC20 internal borrowToken;

    function setupLocal(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(weth), WadRayMath.RAY);
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);
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
            variablePool: address(variablePool) // Aave v3
        });

        implementation = address(new SizeMock());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        size = SizeMock(payable(proxy));

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
        collateralToken = new MockERC20("CollateralToken", "CTK", collateralTokenDecimals);
        borrowToken = new MockERC20("BorrowToken", "BTK", borrowTokenDecimals);
        if (collateralTokenIsWETH) {
            collateralToken = MockERC20(address(weth));
        }
        if (borrowTokenIsWETH) {
            borrowToken = MockERC20(address(weth));
        }

        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(borrowToken), 1.234567e27);

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
            variablePool: address(variablePool)
        });

        implementation = address(new SizeMock());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        size = SizeMock(payable(proxy));

        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function setupProduction(address _owner, address _feeRecipient, NetworkConfiguration memory _networkParams)
        internal
    {
        variablePool = IPool(_networkParams.variablePool);

        if (
            _networkParams.underlyingCollateralTokenAggregator == address(0)
                && _networkParams.underlyingBorrowTokenAggregator == address(0)
        ) {
            priceFeed = new PriceFeedMock(_owner);
            PriceFeedMock(address(priceFeed)).setPrice(2468e18);
        } else {
            priceFeed = new PriceFeed(
                _networkParams.underlyingCollateralTokenAggregator,
                _networkParams.underlyingBorrowTokenAggregator,
                _networkParams.sequencerUptimeFeed,
                _networkParams.underlyingCollateralTokenHeartbeat,
                _networkParams.underlyingBorrowTokenHeartbeat
            );
        }

        if (_networkParams.variablePool == address(0)) {
            variablePool = IPool(address(new PoolMock()));
            PoolMock(address(variablePool)).setLiquidityIndex(
                address(_networkParams.underlyingCollateralToken), WadRayMath.RAY
            );
            PoolMock(address(variablePool)).setLiquidityIndex(
                address(_networkParams.underlyingBorrowToken), WadRayMath.RAY
            );
        } else {
            variablePool = IPool(_networkParams.variablePool);
        }

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: _networkParams.fragmentationFee,
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: _feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: _networkParams.crOpening,
            crLiquidation: _networkParams.crLiquidation,
            minimumCreditBorrowAToken: _networkParams.minimumCreditBorrowAToken,
            borrowATokenCap: _networkParams.borrowATokenCap,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(_networkParams.weth),
            underlyingCollateralToken: address(_networkParams.underlyingCollateralToken),
            underlyingBorrowToken: address(_networkParams.underlyingBorrowToken),
            variablePool: address(variablePool) // Aave v3
        });
        implementation = address(new Size());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
        size = SizeMock(payable(proxy));
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
