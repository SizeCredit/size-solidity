// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {User} from "@src/libraries/fixed/UserLibrary.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

// NOTE changing any of these structs' order or variables may change the storage layout
struct General {
    IPriceFeed priceFeed;
    IMarketBorrowRateFeed marketBorrowRateFeed;
    IERC20Metadata collateralAsset; // e.g. WETH
    IERC20Metadata borrowAsset; // e.g. USDC
    IPool variablePool;
    address insurance;
    address feeRecipient;
}

struct Fixed {
    mapping(address => User) users;
    FixedLoan[] loans;
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAsset;
    uint256 collateralSplitLiquidatorPercent;
    uint256 collateralSplitProtocolPercent;
    CollateralToken collateralToken; // e.g. szWETH
    IAToken borrowAToken; // e.g. aszUSDC
    DebtToken debtToken; // e.g. szDebt
    uint256 collateralTokenCap;
    uint256 borrowATokenCap;
    uint256 debtTokenCap;
    uint256 repayFeeAPR;
}

struct Variable {
    address vaultImplementation;
    uint256 collateralOverdueTransferFee;
}

struct State {
    General _general;
    Fixed _fixed;
    Variable _variable;
}

abstract contract SizeStorage {
    State internal state;
}
