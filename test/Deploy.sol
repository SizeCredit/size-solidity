// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/Size.sol";
import {
    Initialize,
    InitializeFixedParams,
    InitializeGeneralParams,
    InitializeVariableParams
} from "@src/libraries/general/actions/Initialize.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";
import {ScaledBorrowToken} from "@src/token/ScaledBorrowToken.sol";
import {ScaledDebtToken} from "@src/token/ScaledDebtToken.sol";

abstract contract Deploy {
    ERC1967Proxy internal proxy;
    Size internal size;
    PriceFeedMock internal priceFeed;
    WETH internal weth;
    USDC internal usdc;
    CollateralToken internal fixedCollateralToken;
    BorrowToken internal borrowToken;
    DebtToken internal debtToken;
    CollateralToken internal variableCollateralToken;
    ScaledBorrowToken internal scaledBorrowToken;
    ScaledDebtToken internal scaledDebtToken;
    InitializeGeneralParams internal g;
    InitializeFixedParams internal f;
    InitializeVariableParams internal v;

    function setup(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        g = InitializeGeneralParams({
            owner: owner,
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            feeRecipient: feeRecipient
        });
        f = InitializeFixedParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPremiumToLiquidator: 0.3e18,
            collateralPremiumToProtocol: 0.1e18,
            minimumCredit: 5e18
        });
        v = InitializeVariableParams({
            minimumCollateralRatio: 1.5e18,
            minRate: 0.1e18,
            maxRate: 0.5e18,
            slope: 0.1e18,
            optimalUR: 0.8e18,
            reserveFactor: 0.1e18
        });
        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (g, f, v)));
        size = Size(address(proxy));

        priceFeed.setPrice(1337e18);
    }

    function setupChain(address _owner, address _weth, address _usdc) internal {
        priceFeed = new PriceFeedMock(_owner);
        g = InitializeGeneralParams({
            owner: _owner,
            priceFeed: address(priceFeed),
            collateralAsset: _weth,
            borrowAsset: _usdc,
            feeRecipient: _owner
        });
        f = InitializeFixedParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPremiumToLiquidator: 0.3e18,
            collateralPremiumToProtocol: 0.1e18,
            minimumCredit: 5e18
        });
        v = InitializeVariableParams({
            minimumCollateralRatio: 1.5e18,
            minRate: 0.1e18,
            maxRate: 0.5e18,
            slope: 0.1e18,
            optimalUR: 0.8e18,
            reserveFactor: 0.1e18
        });
        size = new Size();
        proxy = new ERC1967Proxy(address(size), abi.encodeCall(Size.initialize, (g, f, v)));
        priceFeed.setPrice(2468e18);
    }
}
