// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

import {USDC} from "./mocks/USDC.sol";
import {WETH} from "./mocks/WETH.sol";
import {Size} from "@src/Size.sol";
import {
    Initialize,
    InitializeFixedParams,
    InitializeGeneralParams,
    InitializeVariableParams
} from "@src/libraries/general/actions/Initialize.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";

import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";
import {ScaledBorrowToken} from "@src/token/ScaledBorrowToken.sol";
import {ScaledDebtToken} from "@src/token/ScaledDebtToken.sol";

contract Deploy {
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
        fixedCollateralToken = new CollateralToken(owner, "Size Fixed ETH", "szETH");
        borrowToken = new BorrowToken(owner, "Size USDC", "szUSDC");
        debtToken = new DebtToken(owner, "Size Debt", "szDebt");
        variableCollateralToken = new CollateralToken(owner, "Size Variable ETH", "szvETH");
        scaledBorrowToken = new ScaledBorrowToken(owner, "Size Variable USDC", "szvUSDC");
        scaledDebtToken = new ScaledDebtToken(owner, "Size Variable Debt", "szvDebt");
        g = InitializeGeneralParams({
            owner: owner,
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            feeRecipient: feeRecipient
        });
        f = InitializeFixedParams({
            collateralToken: address(fixedCollateralToken),
            borrowToken: address(borrowToken),
            debtToken: address(debtToken),
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
            reserveFactor: 0.1e18,
            collateralToken: address(variableCollateralToken),
            scaledBorrowToken: address(scaledBorrowToken),
            scaledDebtToken: address(scaledDebtToken)
        });
        proxy = new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (g, f, v)));
        size = Size(address(proxy));

        fixedCollateralToken.transferOwnership(address(size));
        borrowToken.transferOwnership(address(size));
        debtToken.transferOwnership(address(size));

        variableCollateralToken.transferOwnership(address(size));
        scaledBorrowToken.transferOwnership(address(size));
        scaledDebtToken.transferOwnership(address(size));

        priceFeed.setPrice(1337e18);
    }
}
