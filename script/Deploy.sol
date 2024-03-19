// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {MarketBorrowRateFeed} from "@src/oracle/MarketBorrowRateFeed.sol";

import {VariablePoolPriceFeed} from "@src/oracle/VariablePoolPriceFeed.sol";
import {MarketBorrowRateFeedMock} from "@test/mocks/MarketBorrowRateFeedMock.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/Size.sol";

import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/general/actions/Initialize.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

abstract contract Deploy {
    ERC1967Proxy internal proxy;
    SizeMock internal size;
    IPriceFeed internal priceFeed;
    IMarketBorrowRateFeed internal marketBorrowRateFeed;
    WETH internal weth;
    USDC internal usdc;
    InitializeFeeConfigParams internal f;
    InitializeRiskConfigParams internal r;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;
    IPool internal variablePool;

    function setup(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        marketBorrowRateFeed = new MarketBorrowRateFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock(priceFeed)));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);
        PoolMock(address(variablePool)).setLiquidityIndex(address(weth), WadRayMath.RAY, true);
        f = InitializeFeeConfigParams({
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralOverdueTransferFee: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralSplitLiquidatorPercent: 0.3e18,
            collateralSplitProtocolPercent: 0.1e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            moveToVariablePoolHFThreshold: 1.1e18,
            minimumMaturity: 1 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), marketBorrowRateFeed: address(marketBorrowRateFeed)});
        d = InitializeDataParams({
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool) // Aave v3
        });

        proxy = new ERC1967Proxy(address(new SizeMock()), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        size = SizeMock(address(proxy));

        PriceFeedMock(address(priceFeed)).setPrice(1337e18);
    }

    function setupChain(address _owner, address _weth, address _usdc, address _variablePool, address _aaveOracle)
        internal
    {
        variablePool = IPool(_variablePool);
        priceFeed = new VariablePoolPriceFeed(_aaveOracle, _weth, 8, _usdc, 8, 18);
        marketBorrowRateFeed = new MarketBorrowRateFeed(_owner, 6 hours);
        f = InitializeFeeConfigParams({
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralOverdueTransferFee: 0.1e18,
            feeRecipient: _owner
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralSplitLiquidatorPercent: 0.3e18,
            collateralSplitProtocolPercent: 0.1e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            moveToVariablePoolHFThreshold: 1.1e18,
            minimumMaturity: 1 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), marketBorrowRateFeed: address(marketBorrowRateFeed)});
        d = InitializeDataParams({
            underlyingCollateralToken: address(_weth),
            underlyingBorrowToken: address(_usdc),
            variablePool: address(variablePool) // Aave v3
        });
        size = SizeMock(address(new Size()));
        proxy = new ERC1967Proxy(address(size), abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
    }

    function setupChainWithMocks(address _owner, address _weth, address _usdc) internal {
        priceFeed = new PriceFeedMock(_owner);
        variablePool = IPool(address(new PoolMock(priceFeed)));
        PoolMock(address(variablePool)).setLiquidityIndex(address(_usdc), WadRayMath.RAY);
        PoolMock(address(variablePool)).setLiquidityIndex(address(_weth), WadRayMath.RAY, true);
        PriceFeedMock(address(priceFeed)).setPrice(2468e18);
        marketBorrowRateFeed = new MarketBorrowRateFeedMock(_owner);
        MarketBorrowRateFeedMock(address(marketBorrowRateFeed)).setMarketBorrowRate(0.0724e18);
        f = InitializeFeeConfigParams({
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralOverdueTransferFee: 0.1e18,
            feeRecipient: _owner
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralSplitLiquidatorPercent: 0.3e18,
            collateralSplitProtocolPercent: 0.1e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            moveToVariablePoolHFThreshold: 1.1e18,
            minimumMaturity: 1 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), marketBorrowRateFeed: address(marketBorrowRateFeed)});
        d = InitializeDataParams({
            underlyingCollateralToken: address(_weth),
            underlyingBorrowToken: address(_usdc),
            variablePool: address(variablePool) // Aave v3
        });
        size = SizeMock(address(new Size()));
        proxy = new ERC1967Proxy(address(size), abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
    }
}
