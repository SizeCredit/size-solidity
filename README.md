# size-solidity

<a href="https://github.com/SizeLending/size-solidity/raw/main/size.png"><img src="https://github.com/SizeLending/size-solidity/raw/main/size.png" width="300" alt="Size"/></a>

Size is an order book based fixed rate lending protocol with an integrated variable pool (Aave v3).

Supported pair:

- (W)ETH/USDC: Collateral/Borrow token

Target networks:

- Ethereum mainnet
- Base

## Audits

- [2024-03-19 - LightChaserV3](./audits/2024-03-19-LightChaserV3.md)
- [2024-03-26 - Solidified](./audits/2024-03-26-Solidified.pdf)
- [2024-05-30 - Spearbit (draft)](./audits/2024-05-30-Spearbit-draft.pdf)

## Documentation

### Overview, Accounting and Protocol Design

- [Whitepaper](https://docs.size.cash/)

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
- Underlying borrow and collateral tokens, such as USDC and WETH, are converted 1:1 into deposit tokens via `deposit`, which mints `szaUSDC` and `szWETH`, and received back via `withdraw`, which burns deposit tokens 1:1 in exchange of the underlying tokens.

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

In order to set the current market average value of USDC variable borrow rates, we perform an off-chain calculation on Aave's rate, convert it to 18 decimals, and store it in the contract. For example, a rate of 2.49% on Aave v3 is represented as 24900000000000000. If the oracle information is stale, orders relying on the variable rate feed cannot be matched. The admin can disable this feature by setting the stale interval to zero.

## Test

```bash
forge install
forge test
```

## Coverage

```bash
yarn coverage
```

<!-- BEGIN_COVERAGE -->
### FIles

| File                                                     | % Lines            | % Statements       | % Branches       | % Funcs          |
|----------------------------------------------------------|--------------------|--------------------|------------------|------------------|
| src/Size.sol                                             | 98.21% (55/56)     | 98.28% (57/58)     | 100.00% (0/0)    | 95.24% (20/21)   |
| src/SizeView.sol                                         | 75.76% (25/33)     | 76.36% (42/55)     | 62.50% (5/8)     | 80.95% (17/21)   |
| src/libraries/Math.sol                                   | 95.00% (19/20)     | 93.75% (30/32)     | 100.00% (6/6)    | 88.89% (8/9)     |
| src/libraries/Multicall.sol                              | 100.00% (10/10)    | 100.00% (16/16)    | 100.00% (0/0)    | 100.00% (1/1)    |
| src/libraries/fixed/AccountingLibrary.sol                | 93.75% (75/80)     | 94.85% (92/97)     | 75.00% (21/28)   | 100.00% (11/11)  |
| src/libraries/fixed/CapsLibrary.sol                      | 81.82% (9/11)      | 85.71% (12/14)     | 50.00% (4/8)     | 100.00% (3/3)    |
| src/libraries/fixed/DepositTokenLibrary.sol              | 100.00% (20/20)    | 100.00% (28/28)    | 100.00% (0/0)    | 100.00% (4/4)    |
| src/libraries/fixed/LoanLibrary.sol                      | 96.97% (32/33)     | 97.87% (46/47)     | 93.75% (15/16)   | 100.00% (9/9)    |
| src/libraries/fixed/OfferLibrary.sol                     | 100.00% (10/10)    | 100.00% (22/22)    | 100.00% (4/4)    | 100.00% (6/6)    |
| src/libraries/fixed/RiskLibrary.sol                      | 92.31% (24/26)     | 95.65% (44/46)     | 80.00% (8/10)    | 100.00% (9/9)    |
| src/libraries/fixed/YieldCurveLibrary.sol                | 94.12% (32/34)     | 96.49% (55/57)     | 75.00% (15/20)   | 100.00% (4/4)    |
| src/libraries/fixed/actions/BuyCreditLimit.sol           | 90.00% (9/10)      | 90.91% (10/11)     | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/BuyCreditMarket.sol          | 94.44% (51/54)     | 95.08% (58/61)     | 80.77% (21/26)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/Claim.sol                    | 100.00% (11/11)    | 100.00% (16/16)    | 100.00% (4/4)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/Compensate.sol               | 97.67% (42/43)     | 97.92% (47/48)     | 75.00% (15/20)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/Liquidate.sol                | 100.00% (26/26)    | 100.00% (35/35)    | 83.33% (5/6)     | 100.00% (3/3)    |
| src/libraries/fixed/actions/LiquidateWithReplacement.sol | 93.94% (31/33)     | 95.56% (43/45)     | 80.00% (8/10)    | 100.00% (3/3)    |
| src/libraries/fixed/actions/Repay.sol                    | 100.00% (10/10)    | 100.00% (14/14)    | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SelfLiquidate.sol            | 100.00% (15/15)    | 100.00% (21/21)    | 66.67% (4/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SellCreditLimit.sol          | 100.00% (5/5)      | 100.00% (6/6)      | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/SellCreditMarket.sol         | 95.92% (47/49)     | 96.43% (54/56)     | 82.14% (23/28)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/SetUserConfiguration.sol     | 93.75% (15/16)     | 95.65% (22/23)     | 33.33% (2/6)     | 100.00% (2/2)    |
| src/libraries/general/actions/Deposit.sol                | 95.45% (21/22)     | 96.43% (27/28)     | 85.71% (12/14)   | 100.00% (2/2)    |
| src/libraries/general/actions/Initialize.sol             | 95.45% (63/66)     | 95.95% (71/74)     | 84.38% (27/32)   | 100.00% (11/11)  |
| src/libraries/general/actions/UpdateConfig.sol           | 88.10% (37/42)     | 89.36% (42/47)     | 76.47% (26/34)   | 100.00% (5/5)    |
| src/libraries/general/actions/Withdraw.sol               | 100.00% (16/16)    | 100.00% (21/21)    | 75.00% (9/12)    | 100.00% (2/2)    |
| src/oracle/PriceFeed.sol                                 | 86.96% (20/23)     | 92.50% (37/40)     | 68.75% (11/16)   | 100.00% (3/3)    |
| src/periphery/DexSwap.sol                                | 15.38% (4/26)      | 13.04% (6/46)      | 12.50% (1/8)     | 40.00% (2/5)     |
| src/periphery/FlashLoanLiquidation.sol                   | 85.71% (42/49)     | 84.51% (60/71)     | 40.00% (4/10)    | 83.33% (5/6)     |
| src/token/NonTransferrableScaledToken.sol                | 61.11% (11/18)     | 54.84% (17/31)     | 0.00% (0/2)      | 50.00% (6/12)    |
| src/token/NonTransferrableToken.sol                      | 91.67% (11/12)     | 92.31% (12/13)     | 50.00% (1/2)     | 100.00% (8/8)    |

### Tests per file

```markdown
┌──────────────────────────┬────────┐
│         (index)          │ Values │
├──────────────────────────┼────────┤
│      BuyCreditLimit      │   4    │
│     BuyCreditMarket      │   8    │
│          Claim           │   10   │
│        Compensate        │   15   │
│     CryticToFoundry      │   7    │
│         Deposit          │   5    │
│   FlashLoanLiquidation   │   2    │
│        Initialize        │   4    │
│ LiquidateWithReplacement │   6    │
│        Liquidate         │   10   │
│           Math           │   10   │
│        Multicall         │   7    │
│  NonTransferrableToken   │   7    │
│       OfferLibrary       │   1    │
│          Pause           │   2    │
│        PriceFeed         │   6    │
│          Repay           │   7    │
│      SelfLiquidate       │   10   │
│     SellCreditLimit      │   5    │
│     SellCreditMarket     │   10   │
│   SetUserConfiguration   │   3    │
│         SizeView         │   3    │
│       UpdateConfig       │   7    │
│         Upgrade          │   2    │
│         Withdraw         │   8    │
│        YieldCurve        │   14   │
└──────────────────────────┴────────┘
```
<!-- END_COVERAGE -->

## Protocol invariants

### Invariants implemented

- Check [`PropertiesSpecifications.sol`](./test/invariants/PropertiesSpecifications.sol)

Run Echidna with

```bash
yarn echidna-property
yarn echidna-assertion
```

Check the coverage report with

```bash
yarn echidna-coverage
```

## Formal Verification

- [`Math.min`](./test/libraries/Math.t.sol)
- [`Math.binarySearch`](./test/libraries/Math.t.sol)

Run Halmos with

```bash
for i in {0..5}; do halmos --loop $i; done
```

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
