# size-solidity

<a href="https://raw.githubusercontent.com/SizeLending/size-solidity/main/size.png"><img src="https://raw.githubusercontent.com/SizeLending/size-solidity/main/size.png" width="300" alt="Size"/></a>

Size is an order book based fixed rate lending protocol with an integrated variable pool (Aave v3).

Supported pair:

- (W)ETH/USDC: Collateral/Borrow token

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
| src/Size.sol                                             | 98.11% (52/53)     | 98.18% (54/55)     | 100.00% (0/0)    | 95.00% (19/20)   |
| src/SizeView.sol                                         | 84.85% (28/33)     | 85.45% (47/55)     | 75.00% (6/8)     | 90.48% (19/21)   |
| src/libraries/Math.sol                                   | 95.00% (19/20)     | 93.75% (30/32)     | 100.00% (6/6)    | 88.89% (8/9)     |
| src/libraries/Multicall.sol                              | 100.00% (10/10)    | 100.00% (16/16)    | 100.00% (0/0)    | 100.00% (1/1)    |
| src/libraries/fixed/AccountingLibrary.sol                | 79.22% (61/77)     | 80.65% (75/93)     | 42.31% (11/26)   | 100.00% (11/11)  |
| src/libraries/fixed/CapsLibrary.sol                      | 84.62% (11/13)     | 88.24% (15/17)     | 50.00% (5/10)    | 100.00% (4/4)    |
| src/libraries/fixed/DepositTokenLibrary.sol              | 100.00% (20/20)    | 100.00% (28/28)    | 100.00% (0/0)    | 100.00% (4/4)    |
| src/libraries/fixed/LoanLibrary.sol                      | 96.97% (32/33)     | 97.87% (46/47)     | 93.75% (15/16)   | 100.00% (9/9)    |
| src/libraries/fixed/OfferLibrary.sol                     | 100.00% (16/16)    | 94.12% (32/34)     | 75.00% (6/8)     | 100.00% (6/6)    |
| src/libraries/fixed/RiskLibrary.sol                      | 88.46% (23/26)     | 93.48% (43/46)     | 70.00% (7/10)    | 100.00% (9/9)    |
| src/libraries/fixed/YieldCurveLibrary.sol                | 96.67% (29/30)     | 98.15% (53/54)     | 77.78% (14/18)   | 100.00% (4/4)    |
| src/libraries/fixed/actions/BorrowAsLimitOrder.sol       | 100.00% (5/5)      | 100.00% (6/6)      | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/BuyCreditMarket.sol          | 97.50% (39/40)     | 97.78% (44/45)     | 88.46% (23/26)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/Claim.sol                    | 100.00% (11/11)    | 100.00% (16/16)    | 100.00% (4/4)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/Compensate.sol               | 97.78% (44/45)     | 98.11% (52/53)     | 75.00% (15/20)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsLimitOrder.sol         | 90.00% (9/10)      | 90.91% (10/11)     | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Liquidate.sol                | 100.00% (26/26)    | 100.00% (35/35)    | 83.33% (5/6)     | 100.00% (3/3)    |
| src/libraries/fixed/actions/LiquidateWithReplacement.sol | 93.94% (31/33)     | 95.12% (39/41)     | 80.00% (8/10)    | 100.00% (3/3)    |
| src/libraries/fixed/actions/Repay.sol                    | 100.00% (10/10)    | 100.00% (14/14)    | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SelfLiquidate.sol            | 100.00% (15/15)    | 100.00% (21/21)    | 66.67% (4/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SellCreditMarket.sol         | 97.62% (41/42)     | 97.78% (44/45)     | 78.57% (22/28)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/SetUserConfiguration.sol     | 93.75% (15/16)     | 95.65% (22/23)     | 33.33% (2/6)     | 100.00% (2/2)    |
| src/libraries/general/actions/Deposit.sol                | 95.45% (21/22)     | 96.43% (27/28)     | 85.71% (12/14)   | 100.00% (2/2)    |
| src/libraries/general/actions/Initialize.sol             | 94.20% (65/69)     | 94.87% (74/78)     | 82.35% (28/34)   | 100.00% (11/11)  |
| src/libraries/general/actions/UpdateConfig.sol           | 84.09% (37/44)     | 83.67% (41/49)     | 72.22% (26/36)   | 100.00% (5/5)    |
| src/libraries/general/actions/Withdraw.sol               | 100.00% (16/16)    | 100.00% (21/21)    | 75.00% (9/12)    | 100.00% (2/2)    |
| src/oracle/PriceFeed.sol                                 | 93.75% (15/16)     | 96.55% (28/29)     | 80.00% (8/10)    | 100.00% (3/3)    |
| src/oracle/VariablePoolBorrowRateFeed.sol                | 100.00% (16/16)    | 100.00% (17/17)    | 100.00% (4/4)    | 100.00% (6/6)    |
| src/token/NonTransferrableScaledToken.sol                | 61.11% (11/18)     | 54.84% (17/31)     | 0.00% (0/2)      | 50.00% (6/12)    |
| src/token/NonTransferrableToken.sol                      | 91.67% (11/12)     | 92.31% (12/13)     | 50.00% (1/2)     | 100.00% (8/8)    |

### Tests per file

```markdown
┌────────────────────────────┬────────┐
│          (index)           │ Values │
├────────────────────────────┼────────┤
│     BorrowAsLimitOrder     │   5    │
│      BuyCreditMarket       │   10   │
│           Claim            │   10   │
│         Compensate         │   15   │
│      CryticToFoundry       │   3    │
│          Deposit           │   5    │
│         Initialize         │   4    │
│      LendAsLimitOrder      │   4    │
│  LiquidateWithReplacement  │   6    │
│         Liquidate          │   10   │
│            Math            │   10   │
│         Multicall          │   7    │
│   NonTransferrableToken    │   7    │
│        OfferLibrary        │   1    │
│           Pause            │   2    │
│         PriceFeed          │   7    │
│           Repay            │   7    │
│       SelfLiquidate        │   10   │
│      SellCreditMarket      │   11   │
│    SetUserConfiguration    │   3    │
│          SizeView          │   3    │
│        UpdateConfig        │   7    │
│          Upgrade           │   2    │
│ VariablePoolBorrowRateFeed │   2    │
│          Withdraw          │   8    │
│         YieldCurve         │   14   │
└────────────────────────────┴────────┘
```
<!-- END_COVERAGE -->

## Protocol invariants

### Invariants implemented

- Check [`Properties.sol`](./test/invariants/Properties.sol)

Run Echidna with

```bash
echidna . --contract CryticTester --config echidna.yaml --test-mode property
echidna . --contract CryticTester --config echidna.yaml --test-mode assertion
```

## Formal Verification

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
