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

contract Deploy {
    ERC1967Proxy internal proxy;
    Size internal size;
    PriceFeedMock internal priceFeed;
    WETH internal weth;
    USDC internal usdc;
    CollateralToken internal collateralToken;
    BorrowToken internal borrowToken;
    DebtToken internal debtToken;
    InitializeParams internal params;
    InitializeExtraParams internal extraParams;

    function setup(address owner, address protocolVault, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        collateralToken = new CollateralToken(owner, "Size ETH", "szETH");
        borrowToken = new BorrowToken(owner, "Size USDC", "szUSDC");
        debtToken = new DebtToken(owner, "Size Debt", "szDebt");
        params = InitializeParams({
            owner: owner,
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            collateralToken: address(collateralToken),
            borrowToken: address(borrowToken),
            debtToken: address(debtToken),
            protocolVault: protocolVault,
            feeRecipient: feeRecipient
        });
        extraParams = InitializeExtraParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPercentagePremiumToLiquidator: 0.3e18,
            collateralPercentagePremiumToBorrower: 0.1e18,
            minimumCredit: 5e18
        });
        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (params, extraParams)));
        size = Size(address(proxy));

        collateralToken.transferOwnership(address(size));
        borrowToken.transferOwnership(address(size));
        debtToken.transferOwnership(address(size));

        priceFeed.setPrice(1337e18);
    }
}
