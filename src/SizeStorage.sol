// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWETH} from "@src/interfaces/IWETH.sol";

import {CreditPosition, DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, LoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";

import {NonTransferrableScaledToken} from "@src/token/NonTransferrableScaledToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

struct User {
    LoanOffer loanOffer;
    BorrowOffer borrowOffer;
    uint256 openingLimitBorrowCR;
    bool allCreditPositionsForSaleDisabled;
}

struct FeeConfig {
    uint256 swapFeeAPR; // annual percentage rate of the protocol swap fee
    uint256 fragmentationFee; // fee for fractionalizing credit positions
    uint256 liquidationRewardPercent; // percent of the face value to be given to the liquidator
    uint256 overdueCollateralProtocolPercent; // percent of collateral remainder to be split with protocol on profitable liquidations for overdue loans
    uint256 collateralProtocolPercent; // percent of collateral to be split with protocol on profitable liquidations
    address feeRecipient; // address to receive protocol fees
}

struct RiskConfig {
    uint256 crOpening; // minimum collateral ratio for opening a loan
    uint256 crLiquidation; // maximum collateral ratio for liquidation
    uint256 minimumCreditBorrowAToken; // minimum credit value of loans
    uint256 borrowATokenCap; // maximum amount of deposited borrowed aTokens
    uint256 minimumMaturity; // minimum maturity for a loan
    uint256 maximumMaturity; // maximum maturity for a loan
}

struct Oracle {
    IPriceFeed priceFeed; // price feed oracle
    IVariablePoolBorrowRateFeed variablePoolBorrowRateFeed; // market borrow rate feed oracle
}

struct Data {
    mapping(address => User) users; // mapping of User structs
    mapping(uint256 => DebtPosition) debtPositions; // mapping of DebtPosition structs
    mapping(uint256 => CreditPosition) creditPositions; // mapping of CreditPosition structs
    uint256 nextDebtPositionId; // next debt position id
    uint256 nextCreditPositionId; // next credit position id
    IWETH weth; // Wrapped Ether contract address
    IERC20Metadata underlyingCollateralToken; // the token used by borrowers to collateralize their loans
    IERC20Metadata underlyingBorrowToken; // the token lent from lenders to borrowers
    NonTransferrableToken collateralToken; // Size deposit underlying collateral token
    NonTransferrableScaledToken borrowAToken; // Size deposit underlying borrow aToken
    NonTransferrableToken debtToken; // Size tokenized debt
    IPool variablePool; // Variable Pool (Aave v3)
    bool isMulticall; // Multicall lock to check if multicall is in progress
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
