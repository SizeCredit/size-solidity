// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/Size.sol";
import {
    Initialize, InitializeFixedParams, InitializeGeneralParams
} from "@src/libraries/general/actions/Initialize.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

abstract contract Deploy {
    ERC1967Proxy internal proxy;
    Size internal size;
    PriceFeedMock internal priceFeed;
    WETH internal weth;
    USDC internal usdc;
    InitializeGeneralParams internal g;
    InitializeFixedParams internal f;
    IPool internal variablePool;

    function setup(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);
        g = InitializeGeneralParams({
            owner: owner,
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            feeRecipient: feeRecipient,
            variablePool: address(variablePool)
        });
        f = InitializeFixedParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPremiumToLiquidator: 0.3e18,
            collateralPremiumToProtocol: 0.1e18,
            minimumCreditBorrowAsset: 5e6
        });
        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (g, f)));
        size = Size(address(proxy));

        priceFeed.setPrice(1337e18);
    }

    function setupChain(address _owner, address pool, address _weth, address _usdc) internal {
        variablePool = IPool(pool);
        priceFeed = new PriceFeedMock(_owner);
        g = InitializeGeneralParams({
            owner: _owner,
            priceFeed: address(priceFeed),
            collateralAsset: _weth,
            borrowAsset: _usdc,
            feeRecipient: _owner,
            variablePool: address(variablePool)
        });
        f = InitializeFixedParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPremiumToLiquidator: 0.3e18,
            collateralPremiumToProtocol: 0.1e18,
            minimumCreditBorrowAsset: 5e6
        });
        size = new Size();
        proxy = new ERC1967Proxy(address(size), abi.encodeCall(Size.initialize, (g, f)));
        priceFeed.setPrice(2468e18);
    }
}
