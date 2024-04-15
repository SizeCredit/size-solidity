# size-solidity

![Size](./size.png)

Size is an order book based fixed rate lending protocol with an integrated variable pool (Aave v3).

Initial pairs (each pair will be a new deployment of the whole Size protocol):

- (W)ETH/USDC: Collateral/Borrow token (regular ETH market)
- USDC/(W)ETH: Collateral/Borrow token (reverse ETH market)

Target networks:

- Ethereum mainnet
- Base

## Audits

- [LightChaserV3](./audits/2024-03-19-LightChaserV3_SizeV2.md)
- [Solidified](./audits/2024-03-26-Solidified.pdf)

## Documentation

### Overview, Accounting and Protocol Design

- [Whitepaper](https://size-lending.gitbook.io/size-v2/)

### Technical overview

#### Architecture

The architecture of Size v2 was inspired by [dYdX v2](https://github.com/dydxprotocol/solo), with the following design goals:

- Upgradeability
- Modularity
- Overcome [EIP-170](https://eips.ethereum.org/EIPS/eip-170)'s contract code size limit of 24kb
- Maintaining the protocol invariants after each user interaction (["FREI-PI" pattern](https://www.nascent.xyz/idea/youre-writing-require-statements-wrong))

For that purpose, the contract is deployed behind an UUPS-Upgradeable proxy, and contains a single entrypoint, `Size.sol`. External libraries are used, and a single `State storage` variable is passed to them via `delegatecall`s. All user-facing functions have the same pattern:

```solidity
state.validateFunction(params);
state.executeFunction(params);
state.validateInvariant(params);
```

The `Multicall` pattern is also available to allow users to perform a sequence of multiple actions, such as depositing borrow tokens, liquidating an underwater borrower, and withdrawing all liquidated collateral. Note: in order to accept ether deposits through multicalls, all user-facing functions have the [`payable`](https://github.com/sherlock-audit/2023-06-tokemak-judging/issues/215) modifier, and `deposit` always uses `address(this).balance` to wrap ether, meaning that leftover amounts, if [sent forcibly](https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/force-feeding/), are always credited to the depositor.

Additional safety features were employed, such as different levels of Access Control (ADMIN, PAUSER_ROLE, KEEPER_ROLE), and Pause.

#### Tokens

In order to address donation and reentrancy attacks, the following measures were adopted:

- No withdraws of native ether, only wrapped ether (WETH)
- Underlying borrow and collateral tokens, such as USDC and WETH, are converted 1:1 into protocol tokens via `deposit`, which mints `aUSDC` and `szWETH`, and received back via `withdraw`, which burns protocol tokens 1:1 in exchange of the underlying tokens.

#### Maths

All mathematical operations are implemented with explicit rounding (`mulDivUp` or `mulDivDown`) using Solady's [FixedPointMathLib](https://github.com/Vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol). Whenever a taker-maker operation occurs, all rounding tries to favor the maker, who is the passive party except in yield curve calculations, which always round down.

Decimal amounts are preserved until a conversion is necessary:

- USDC/aUSDC: 6 decimals
- WETH/szETH: 18 decimals
- szDebt: same as borrow token
- VariablePoolPriceFeed (ETH/USDC or USDC/ETH): 18 decimals
- MarketBorrowRateFeed (USDC or ETH): 18 decimals

All percentages are expressed in 18 decimals. For example, a 150% liquidation collateral ratio is represented as 1500000000000000000.

#### Variable Pool

In order to interact with Aave v3, a library is used to track scaled deposits of users, which represent the deposits of underlying borrow tokens divided by the liquidity index at each time.

#### Oracles

##### Price Feed

A contract that provides the price of ETH in terms of USDC in 18 decimals. For example, a price of 3327.39 ETH/USDC is represented as 3327390000000000000000.

##### Variable Pool Borrow Rate Feed

In order to set the current market average value of USDC variable borrow rates, we perform an off-chain calculation on Aave's rate, convert it to 18 decimals, and store it on the oracle. For example, a rate of 2.49% on Aave v3 is represented as 24900000000000000.

## Test

```bash
forge install
forge test
```

## Coverage

<!-- BEGIN_COVERAGE -->
### FIles

| File                                                     | % Lines            | % Statements       | % Branches       | % Funcs          |
|----------------------------------------------------------|--------------------|--------------------|------------------|------------------|
| src/Size.sol                                             | 98.31% (58/59)     | 98.36% (60/61)     | 100.00% (0/0)    | 95.00% (19/20)   |
| src/SizeView.sol                                         | 68.42% (26/38)     | 74.24% (49/66)     | 25.00% (2/8)     | 82.61% (19/23)   |
| src/libraries/Math.sol                                   | 100.00% (20/20)    | 100.00% (32/32)    | 100.00% (6/6)    | 100.00% (9/9)    |
| src/libraries/fixed/AccountingLibrary.sol                | 100.00% (32/32)    | 100.00% (41/41)    | 75.00% (3/4)     | 83.33% (5/6)     |
| src/libraries/fixed/CapsLibrary.sol                      | 88.89% (8/9)       | 92.31% (12/13)     | 50.00% (4/8)     | 100.00% (4/4)    |
| src/libraries/fixed/CollateralLibrary.sol                | 100.00% (6/6)      | 100.00% (8/8)      | 100.00% (0/0)    | 100.00% (2/2)    |
| src/libraries/fixed/LoanLibrary.sol                      | 95.83% (46/48)     | 95.89% (70/73)     | 93.75% (15/16)   | 93.33% (14/15)   |
| src/libraries/fixed/OfferLibrary.sol                     | 100.00% (16/16)    | 88.89% (32/36)     | 50.00% (4/8)     | 100.00% (6/6)    |
| src/libraries/fixed/RiskLibrary.sol                      | 91.67% (22/24)     | 95.12% (39/41)     | 80.00% (8/10)    | 100.00% (8/8)    |
| src/libraries/fixed/YieldCurveLibrary.sol                | 100.00% (28/28)    | 100.00% (52/52)    | 87.50% (14/16)   | 100.00% (4/4)    |
| src/libraries/fixed/actions/BorrowAsLimitOrder.sol       | 100.00% (5/5)      | 100.00% (6/6)      | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/BorrowAsMarketOrder.sol      | 98.28% (57/58)     | 98.55% (68/69)     | 95.83% (23/24)   | 100.00% (4/4)    |
| src/libraries/fixed/actions/BorrowerExit.sol             | 97.14% (34/35)     | 97.56% (40/41)     | 90.00% (9/10)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/BuyMarketCredit.sol          | 82.86% (29/35)     | 85.37% (35/41)     | 68.75% (11/16)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/Claim.sol                    | 100.00% (11/11)    | 100.00% (16/16)    | 100.00% (4/4)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/Compensate.sol               | 100.00% (40/40)    | 100.00% (44/44)    | 93.75% (15/16)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsLimitOrder.sol         | 90.00% (9/10)      | 90.00% (9/10)      | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsMarketOrder.sol        | 100.00% (21/21)    | 100.00% (23/23)    | 100.00% (10/10)  | 100.00% (2/2)    |
| src/libraries/fixed/actions/Liquidate.sol                | 100.00% (34/34)    | 100.00% (44/44)    | 66.67% (4/6)     | 100.00% (4/4)    |
| src/libraries/fixed/actions/LiquidateWithReplacement.sol | 94.44% (34/36)     | 95.45% (42/44)     | 80.00% (8/10)    | 100.00% (3/3)    |
| src/libraries/fixed/actions/Repay.sol                    | 100.00% (17/17)    | 100.00% (23/23)    | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SelfLiquidate.sol            | 100.00% (24/24)    | 100.00% (32/32)    | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SetCreditForSale.sol         | 92.86% (13/14)     | 95.24% (20/21)     | 33.33% (2/6)     | 100.00% (2/2)    |
| src/libraries/general/actions/Deposit.sol                | 94.74% (18/19)     | 96.00% (24/25)     | 75.00% (9/12)    | 100.00% (2/2)    |
| src/libraries/general/actions/Initialize.sol             | 94.67% (71/75)     | 95.24% (80/84)     | 88.89% (32/36)   | 100.00% (11/11)  |
| src/libraries/general/actions/UpdateConfig.sol           | 82.22% (37/45)     | 81.63% (40/49)     | 80.56% (29/36)   | 66.67% (4/6)     |
| src/libraries/general/actions/Withdraw.sol               | 100.00% (16/16)    | 100.00% (21/21)    | 75.00% (9/12)    | 100.00% (2/2)    |
| src/libraries/variable/VariablePoolLibrary.sol           | 94.74% (18/19)     | 96.67% (29/30)     | 75.00% (3/4)     | 100.00% (5/5)    |
| src/oracle/PriceFeed.sol                                 | 100.00% (12/12)    | 100.00% (21/21)    | 100.00% (8/8)    | 100.00% (3/3)    |
| src/oracle/VariablePoolBorrowRateFeed.sol                | 100.00% (10/10)    | 100.00% (11/11)    | 100.00% (2/2)    | 100.00% (3/3)    |
| src/proxy/Multicall.sol                                  | 75.00% (3/4)       | 83.33% (5/6)       | 100.00% (0/0)    | 100.00% (1/1)    |
| src/token/NonTransferrableToken.sol                      | 100.00% (9/9)      | 100.00% (10/10)    | 100.00% (0/0)    | 100.00% (7/7)    |

### Scenarios

```markdown
┌────────────────────────────┬────────┐
│          (index)           │ Values │
├────────────────────────────┼────────┤
│     BorrowAsLimitOrder     │   4    │
│    BorrowAsMarketOrder     │   14   │
│        BorrowerExit        │   7    │
│      BuyMarketCredit       │   2    │
│           Claim            │   10   │
│         Compensate         │   8    │
│      CryticToFoundry       │   1    │
│          Deposit           │   4    │
│         Initialize         │   4    │
│      LendAsLimitOrder      │   3    │
│     LendAsMarketOrder      │   7    │
│  LiquidateWithReplacement  │   6    │
│         Liquidate          │   10   │
│            Math            │   10   │
│         Multicall          │   6    │
│   NonTransferrableToken    │   7    │
│           Pause            │   2    │
│         PriceFeed          │   9    │
│           Repay            │   6    │
│       SelfLiquidate        │   13   │
│      SetCreditForSale      │   3    │
│        UpdateConfig        │   4    │
│          Upgrade           │   2    │
│ VariablePoolBorrowRateFeed │   2    │
│          Withdraw          │   8    │
│         YieldCurve         │   13   │
└────────────────────────────┴────────┘
```
<!-- END_COVERAGE -->

## Protocol invariants

### Invariants implemented

- Check [`Properties.sol`](./test/invariants/Properties.sol)

### Invariants pending implementation

- Taking a loan with only receivables does not decrease the borrower CR
- Taking a collateralized loan decreases the borrower CR
- The user cannot withdraw more than their deposits
- If the loan is liquidatable, the liquidation should not revert
- When a user self liquidates a CreditPosition, it will improve the collateralization ratio of other CreditPosition. This is because self liquidating decreases the DebtPosition's faceValue, so it decreases all CreditPosition's assigned collateral

## Known limitations

- The protocol does not support rebasing tokens
- The protocol does not support fee-on-transfer tokens
- The protocol does not support tokens with more than 18 decimals
- The protocol only supports tokens compliant with the IERC20Metadata interface
- The protocol only supports pre-vetted tokens
- The protocol owner, KEEPER_ROLE, and PAUSER_ROLE are trusted
- The protocol does not have any fallback oracles.
- Price feeds must be redeployed and updated in case any Chainlink configuration changes (stale price timeouts, decimals)
- In case Chainlink reports a wrong price, the protocol state cannot be guaranteed. This may cause incorrect liquidations, among other issues
- In case the protocol is paused, the price of the collateral may change during the unpause event. This may cause unforseen liquidations, among other issues
- Users blocklisted by underlying tokens (e.g. USDC) may be unable to withdraw or interact with the protocol
- Protocol fees may prevent self liquidations
- All issues acknowledged on previous audits

## Deployment

```bash
source .env
CHAIN_NAME=$CHAIN_NAME DEPLOYER_ADDRESS=$DEPLOYER_ADDRESS yarn deploy --broadcast
```
