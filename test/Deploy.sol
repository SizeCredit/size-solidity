// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {MarketBorrowRateFeedMock} from "@test/mocks/MarketBorrowRateFeedMock.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/Size.sol";
import {
    Initialize,
    InitializeConfigParams,
    InitializeDataParams,
    InitializeOracleParams
} from "@src/libraries/general/actions/Initialize.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

abstract contract Deploy {
    ERC1967Proxy internal proxy;
    Size internal size;
    PriceFeedMock internal priceFeed;
    MarketBorrowRateFeedMock internal marketBorrowRateFeed;
    WETH internal weth;
    USDC internal usdc;
    InitializeConfigParams internal c;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;
    IPool internal variablePool;

    function setup(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        marketBorrowRateFeed = new MarketBorrowRateFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);
        c = InitializeConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralSplitLiquidatorPercent: 0.3e18,
            collateralSplitProtocolPercent: 0.1e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralOverdueTransferFee: 0.1e18,
            feeRecipient: feeRecipient
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), marketBorrowRateFeed: address(marketBorrowRateFeed)});
        d = InitializeDataParams({
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool) // Aave v3 fork
        });

        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (owner, c, o, d)));
        size = Size(address(proxy));

        priceFeed.setPrice(1337e18);
    }

    function setupChainMocks(address _owner, address _weth, address _usdc) internal {
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(_usdc, WadRayMath.RAY);
        priceFeed = new PriceFeedMock(_owner);
        priceFeed.setPrice(2468e18);
        marketBorrowRateFeed = new MarketBorrowRateFeedMock(_owner);
        marketBorrowRateFeed.setMarketBorrowRate(0.0724e18);
        c = InitializeConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralSplitLiquidatorPercent: 0.2e18,
            collateralSplitProtocolPercent: 0.2e18,
            minimumCreditBorrowAToken: 50e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralOverdueTransferFee: 0.005e18,
            feeRecipient: _owner
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), marketBorrowRateFeed: address(marketBorrowRateFeed)});
        d = InitializeDataParams({
            underlyingCollateralToken: address(_weth),
            underlyingBorrowToken: address(_usdc),
            variablePool: address(variablePool) // Aave v3 fork
        });
        size = new Size();
        proxy = new ERC1967Proxy(address(size), abi.encodeCall(Size.initialize, (_owner, c, o, d)));
    }
}
