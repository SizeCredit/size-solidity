// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";

import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

struct FeeConfig {
    uint256 repayFeeAPR; // annual percentage rate of the protocol repay fee
    uint256 earlyLenderExitFee; // fee for early lender exits
    uint256 earlyBorrowerExitFee; // fee for early borrower exits
    uint256 collateralOverdueTransferFee; // fee for converting overdue fixed-rate loans into the variable-rate loans
    address feeRecipient; // address to receive protocol fees
}

struct RiskConfig {
    uint256 crOpening; // minimum collateral ratio for opening a loan
    uint256 crLiquidation; // minimum collateral ratio for liquidation
    uint256 minimumCreditBorrowAToken; // minimum credit value of loans
    uint256 collateralSplitLiquidatorPercent; // percent of collateral remainder to be split with liquidator on profitable liquidations
    uint256 collateralSplitProtocolPercent; // percent of collateral to be split with protocol on profitable liquidations
    uint256 collateralTokenCap; // maximum amount of deposited collateral tokens
    uint256 borrowATokenCap; // maximum amount of deposited borrowed aTokens
    uint256 debtTokenCap; // maximum amount of minted debt tokens
    uint256 moveToVariablePoolHFThreshold; // health factor threshold for moving a loan to the variable pool
    uint256 minimumMaturity; // minimum loan maturity
}

struct Oracle {
    IPriceFeed priceFeed; // price feed oracle
    IMarketBorrowRateFeed marketBorrowRateFeed; // market borrow rate feed oracle
}

struct Data {
    mapping(address => User) users; // mapping of User structs
    mapping(address => bool) variablePoolAllowlisted; // mapping of addresses allowlisted to interact with the Variable Pool
    Loan[] loans; // array of Loan structs
    IERC20Metadata underlyingCollateralToken; // e.g. WETH
    IERC20Metadata underlyingBorrowToken; // e.g. USDC
    NonTransferrableToken collateralToken; // e.g. szWETH
    IAToken borrowAToken; // e.g. aszUSDC
    IAToken collateralAToken; // e.g. aszWETH
    NonTransferrableToken debtToken; // e.g. szDebt
    IPool variablePool; // Size Variable Pool (Aave v3 fork)
    Vault vaultImplementation; // Vault implementation
}

struct State {
    FeeConfig feeConfig;
    RiskConfig riskConfig;
    Oracle oracle;
    Data data;
}

/// @title SizeStorage
/// @notice Storage for the Size protocol
/// @dev WARNING: Changing the order of the variables or inner structs in this contract may break the storage layout
abstract contract SizeStorage {
    State internal state;
}
