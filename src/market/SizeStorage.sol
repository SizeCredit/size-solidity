// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWETH} from "@src/market/interfaces/IWETH.sol";

import {CreditPosition, DebtPosition} from "@src/market/libraries/LoanLibrary.sol";
import {CopyLimitOrderConfig, LimitOrder} from "@src/market/libraries/OfferLibrary.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {NonTransferrableToken} from "@src/market/token/NonTransferrableToken.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

struct User {
    // The user's loan offer
    LimitOrder loanOffer;
    // The user's borrow offer
    LimitOrder borrowOffer;
    // The user-defined opening limit CR. If not set, the protocol's crOpening is used.
    uint256 openingLimitBorrowCR;
    // Whether the user has disabled all credit positions for sale
    bool allCreditPositionsForSaleDisabled;
}

struct UserCopyLimitOrderConfigs {
    // deprecated in v1.8
    address ___deprecated_copyAddress;
    // the loan offer copy parameters
    CopyLimitOrderConfig copyLoanOfferConfig;
    // the borrow offer copy parameters
    CopyLimitOrderConfig copyBorrowOfferConfig;
}

struct FeeConfig {
    // annual percentage rate of the protocol swap fee
    uint256 swapFeeAPR;
    // fee for fractionalizing credit positions
    uint256 fragmentationFee;
    // percent of the futureValue to be given to the liquidator
    uint256 liquidationRewardPercent;
    // percent of collateral remainder to be split with protocol on profitable liquidations for overdue loans
    uint256 overdueCollateralProtocolPercent;
    // percent of collateral to be split with protocol on profitable liquidations
    uint256 collateralProtocolPercent;
    // address to receive protocol fees
    address feeRecipient;
}

struct RiskConfig {
    // minimum collateral ratio for opening a loan
    uint256 crOpening;
    // maximum collateral ratio for liquidation
    uint256 crLiquidation;
    // minimum credit value of loans
    uint256 minimumCreditBorrowToken;
    // maximum amount of deposited borrowed tokens (deprecated in v1.8)
    uint256 ___deprecated_borrowTokenCap;
    // minimum tenor for a loan
    uint256 minTenor;
    // maximum tenor for a loan
    uint256 maxTenor;
}

struct Oracle {
    // price feed oracle
    IPriceFeed priceFeed;
    // variable pool borrow rate
    uint128 variablePoolBorrowRate;
    // timestamp of the last update
    uint64 variablePoolBorrowRateUpdatedAt;
    // stale rate interval
    uint64 variablePoolBorrowRateStaleRateInterval;
}

struct Data {
    // mapping of User structs
    mapping(address => User) users;
    // mapping of DebtPosition structs
    mapping(uint256 => DebtPosition) debtPositions;
    // mapping of CreditPosition structs
    mapping(uint256 => CreditPosition) creditPositions;
    // next debt position id
    uint256 nextDebtPositionId;
    // next credit position id
    uint256 nextCreditPositionId;
    // Wrapped Ether contract address
    IWETH weth;
    // the token used by borrowers to collateralize their loans
    IERC20Metadata underlyingCollateralToken;
    // the token lent from lenders to borrowers
    IERC20Metadata underlyingBorrowToken;
    // Size deposit underlying collateral token
    NonTransferrableToken collateralToken;
    // Size deposit underlying borrow aToken v1.2 (deprecated in v1.5)
    address ___deprecated_borrowATokenV1_2;
    // Size tokenized debt
    NonTransferrableToken debtToken;
    // Variable Pool (Aave v3)
    IPool variablePool;
    // Multicall lock to check if multicall is in progress (deprecated in v1.8)
    bool ___deprecated_isMulticall;
    // Size deposit underlying borrow token (upgraded in v1.8)
    NonTransferrableRebasingTokenVault borrowTokenVault;
    // mapping of copy limit order configs (added in v1.6.1, updated in v1.8)
    mapping(address => UserCopyLimitOrderConfigs) usersCopyLimitOrderConfigs;
    // Size Factory (added in v1.7)
    ISizeFactory sizeFactory;
}

struct State {
    // the fee configuration struct
    FeeConfig feeConfig;
    // the risk configuration struct
    RiskConfig riskConfig;
    // the oracle configuration struct
    Oracle oracle;
    // the protocol data (cannot be updated)
    Data data;
}

/// @title SizeStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Storage for the Size protocol
/// @dev WARNING: Changing the order of the variables or inner structs in this contract may break the storage layout
abstract contract SizeStorage {
    State internal state;
}
