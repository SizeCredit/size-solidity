// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

import {USDC} from "./mocks/USDC.sol";
import {WETH} from "./mocks/WETH.sol";
import {Size} from "@src/Size.sol";
import {InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {DebtToken} from "@src/token/DebtToken.sol";

abstract contract Deploy {
    ERC1967Proxy internal proxy;
    Size internal size;
    PriceFeedMock internal priceFeed;
    WETH internal weth;
    USDC internal usdc;
    InitializeParams internal params;
    InitializeExtraParams internal extraParams;

    function setup(address owner, address variablePool, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        params = InitializeParams({
            owner: owner,
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            variablePool: variablePool,
            feeRecipient: feeRecipient
        });
        extraParams = InitializeExtraParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPremiumToLiquidator: 0.3e18,
            collateralPremiumToProtocol: 0.1e18,
            minimumCredit: 5e18
        });
        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (params, extraParams)));
        size = Size(address(proxy));

        priceFeed.setPrice(1337e18);
    }

    function setupChain(address _owner, address _weth, address _usdc) internal {
        priceFeed = new PriceFeedMock(_owner);
        params = InitializeParams({
            owner: _owner,
            priceFeed: address(priceFeed),
            collateralAsset: address(_weth),
            borrowAsset: address(_usdc),
            variablePool: address(0x1),
            feeRecipient: _owner
        });
        extraParams = InitializeExtraParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPremiumToLiquidator: 0.3e18,
            collateralPremiumToProtocol: 0.1e18,
            minimumCredit: 5e18
        });
        size = new Size();
        proxy = new ERC1967Proxy(address(size), abi.encodeCall(Size.initialize, (params, extraParams)));
        priceFeed.setPrice(2468e18);
    }
}
