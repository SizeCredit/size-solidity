// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";

import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

struct Config {
    uint256 crOpening;
    uint256 crLiquidation;
    uint256 minimumCreditBorrowAToken;
    uint256 collateralSplitLiquidatorPercent;
    uint256 collateralSplitProtocolPercent;
    uint256 collateralTokenCap;
    uint256 borrowATokenCap;
    uint256 debtTokenCap;
    uint256 repayFeeAPR;
    uint256 earlyLenderExitFee;
    uint256 earlyBorrowerExitFee;
    uint256 collateralOverdueTransferFee;
    address feeRecipient;
}

struct Oracle {
    IPriceFeed priceFeed;
    IMarketBorrowRateFeed marketBorrowRateFeed;
}

struct Data {
    mapping(address => User) users;
    Loan[] loans;
    IERC20Metadata underlyingCollateralToken; // e.g. WETH
    IERC20Metadata underlyingBorrowToken; // e.g. USDC
    NonTransferrableToken collateralToken; // e.g. szWETH
    IAToken borrowAToken; // e.g. aszUSDC
    NonTransferrableToken debtToken; // e.g. szDebt
    IPool variablePool;
    Vault vaultImplementation;
}

struct State {
    Config config;
    Oracle oracle;
    Data data;
}

/// @title SizeStorage
/// @notice Storage for the Size protocol
/// @dev WARNING: Changing the order of the variables or inner structs in this contract may break the storage layout
abstract contract SizeStorage {
    State internal state;
}
