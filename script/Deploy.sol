// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";

import {VariablePoolBorrowRateFeed} from "@src/oracle/VariablePoolBorrowRateFeed.sol";

import {PriceFeed} from "@src/oracle/PriceFeed.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import {VariablePoolBorrowRateFeedMock} from "@test/mocks/VariablePoolBorrowRateFeedMock.sol";

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
    address internal implementation;
    address internal proxy;
    SizeMock internal size;
    IPriceFeed internal priceFeed;
    IVariablePoolBorrowRateFeed internal variablePoolBorrowRateFeed;
    WETH internal weth;
    USDC internal usdc;
    InitializeFeeConfigParams internal f;
    InitializeRiskConfigParams internal r;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;
    IPool internal variablePool;

    function setupLocal(address _owner, address _feeRecipient) internal {
        priceFeed = new PriceFeedMock(_owner);
        variablePoolBorrowRateFeed = new VariablePoolBorrowRateFeedMock(_owner);
        weth = new WETH();
        usdc = new USDC(_owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);
        f = InitializeFeeConfigParams({
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralLiquidatorPercent: 0.3e18,
            collateralProtocolPercent: 0.1e18,
            overdueLiquidatorReward: 10e6,
            overdueColLiquidatorPercent: 0.01e18,
            overdueColProtocolPercent: 0.005e18,
            feeRecipient: _feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            minimumMaturity: 1 days
        });
        o = InitializeOracleParams({
            priceFeed: address(priceFeed),
            variablePoolBorrowRateFeed: address(variablePoolBorrowRateFeed)
        });
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool) // Aave v3
        });

        proxy = Upgrades.deployUUPSProxy("SizeMock.sol", abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
        implementation = Upgrades.getImplementationAddress(proxy);
        size = SizeMock(payable(proxy));

        PriceFeedMock(address(priceFeed)).setPrice(1337e18);
    }

    function setupProduction(
        address _owner,
        address _weth,
        address _usdc,
        address _variablePool,
        address _wethAggregator,
        address _usdcAggregator
    ) internal {
        variablePool = IPool(_variablePool);
        priceFeed = new PriceFeed(_wethAggregator, _usdcAggregator, 18, 3600 * 1.1e18 / 1e18, 86400 * 1.1e18 / 1e18);
        variablePoolBorrowRateFeed = new VariablePoolBorrowRateFeed(_owner, 6 hours);
        f = InitializeFeeConfigParams({
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralLiquidatorPercent: 0.3e18,
            collateralProtocolPercent: 0.1e18,
            overdueLiquidatorReward: 10e6,
            overdueColLiquidatorPercent: 0.01e18,
            overdueColProtocolPercent: 0.01e18,
            feeRecipient: _owner
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            minimumMaturity: 1 days
        });
        o = InitializeOracleParams({
            priceFeed: address(priceFeed),
            variablePoolBorrowRateFeed: address(variablePoolBorrowRateFeed)
        });
        d = InitializeDataParams({
            weth: address(_weth),
            underlyingCollateralToken: address(_weth),
            underlyingBorrowToken: address(_usdc),
            variablePool: address(variablePool) // Aave v3
        });
        proxy = Upgrades.deployUUPSProxy("Size.sol", abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
        implementation = Upgrades.getImplementationAddress(proxy);
        size = SizeMock(payable(proxy));
    }

    function setupTestnet(address _owner, address _weth, address _usdc) internal {
        priceFeed = new PriceFeedMock(_owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(_usdc), WadRayMath.RAY);
        PriceFeedMock(address(priceFeed)).setPrice(2468e18);
        variablePoolBorrowRateFeed = new VariablePoolBorrowRateFeedMock(_owner);
        VariablePoolBorrowRateFeedMock(address(variablePoolBorrowRateFeed)).setVariableBorrowRate(0.0724e18);
        f = InitializeFeeConfigParams({
            repayFeeAPR: 0.005e18,
            earlyLenderExitFee: 5e6,
            earlyBorrowerExitFee: 1e6,
            collateralLiquidatorPercent: 0.3e18,
            collateralProtocolPercent: 0.1e18,
            overdueLiquidatorReward: 10e6,
            overdueColLiquidatorPercent: 0.01e18,
            overdueColProtocolPercent: 0.01e18,
            feeRecipient: _owner
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowAToken: 5e6,
            collateralTokenCap: 1000e18,
            borrowATokenCap: 1_000_000e6,
            debtTokenCap: 500_000e6,
            minimumMaturity: 1 days
        });
        o = InitializeOracleParams({
            priceFeed: address(priceFeed),
            variablePoolBorrowRateFeed: address(variablePoolBorrowRateFeed)
        });
        d = InitializeDataParams({
            weth: address(_weth),
            underlyingCollateralToken: address(_weth),
            underlyingBorrowToken: address(_usdc),
            variablePool: address(variablePool) // Aave v3
        });
        proxy = Upgrades.deployUUPSProxy("Size.sol", abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
        implementation = Upgrades.getImplementationAddress(proxy);
        size = SizeMock(payable(proxy));
    }
}
