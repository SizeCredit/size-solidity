# size-solidity

<a href="https://github.com/SizeLending/size-solidity/raw/main/size.png"><img src="https://github.com/SizeLending/size-solidity/raw/main/size.png" width="300" alt="Size"/></a>

Size is a credit marketplace with unified liquidity across maturities.

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

The `Multicall` pattern is also available to allow users to perform a sequence of multiple actions, such as depositing borrow tokens, liquidating an underwater borrower, and withdrawing all liquidated collateral. **Note:** in order to accept ether deposits through multicalls, all user-facing functions have the [`payable`](https://github.com/sherlock-audit/2023-06-tokemak-judging/issues/215) modifier, and `deposit` always uses `address(this).balance` to wrap ether. This means leftover amounts, if [sent forcibly](https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/force-feeding/), are always credited to the depositor.

Additional safety features were employed, such as different levels of Access Control (ADMIN, PAUSER_ROLE, KEEPER_ROLE, BORROW_RATE_UPDATER_ROLE), and Pause.

#### Tokens

In order to address donation and reentrancy attacks, the following measures were adopted:

- No withdraws of native ether, only wrapped ether (WETH)
- Underlying borrow and collateral tokens, such as USDC and WETH, are converted 1:1 into deposit tokens via `deposit`, which mints `szaUSDC` and `szWETH`, and received back via `withdraw`, which burns deposit tokens 1:1 in exchange for the underlying tokens.

#### Maths

All mathematical operations are implemented with explicit rounding (`mulDivUp` or `mulDivDown`) using Solady's [FixedPointMathLib](https://github.com/Vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol). Whenever a taker-maker operation occurs, all rounding tries to favor the maker, who is the passive party. In some generic situations, such as in yield curve calculations, the rounding is always in one direction.

Decimal amounts are preserved until a conversion is necessary:

- USDC/aUSDC: 6 decimals
- WETH/szETH: 18 decimals
- szDebt: same as borrow token
- Price feeds: 18 decimals

All percentages are expressed in 18 decimals. For example, a 150% liquidation collateral ratio is represented as 1500000000000000000.

#### Oracles

##### Price Feed

A contract that provides the price of ETH in terms of USDC in 18 decimals. For example, a price of 3327.39 ETH/USDC is represented as 3327390000000000000000.

##### Variable Pool Borrow Rate Feed

In order to set the current market average value of USDC variable borrow rates, we perform an off-chain calculation on Aave's rate, convert it to 18 decimals, and store it in the Size contract. For example, a rate of 2.49% on Aave v3 is represented as 24900000000000000. The admin can disable this feature by setting the stale interval to zero. If the oracle information is stale, orders relying on the variable rate feed cannot be matched.

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

| File                                               | % Lines            | % Statements       | % Branches       | % Funcs          |
|----------------------------------------------------|--------------------|--------------------|------------------|------------------|
| src/Size.sol                                       | 100.00% (58/58)    | 100.00% (60/60)    | 100.00% (4/4)    | 100.00% (21/21)  |
| src/SizeView.sol                                   | 100.00% (28/28)    | 100.00% (47/47)    | 100.00% (6/6)    | 100.00% (19/19)  |
| src/libraries/AccountingLibrary.sol                | 95.06% (77/81)     | 95.74% (90/94)     | 82.14% (23/28)   | 100.00% (12/12)  |
| src/libraries/CapsLibrary.sol                      | 81.82% (9/11)      | 85.71% (12/14)     | 50.00% (4/8)     | 100.00% (3/3)    |
| src/libraries/DepositTokenLibrary.sol              | 100.00% (20/20)    | 100.00% (28/28)    | 100.00% (0/0)    | 100.00% (4/4)    |
| src/libraries/LoanLibrary.sol                      | 96.88% (31/32)     | 97.83% (45/46)     | 93.75% (15/16)   | 100.00% (8/8)    |
| src/libraries/Math.sol                             | 100.00% (18/18)    | 100.00% (28/28)    | 100.00% (6/6)    | 100.00% (7/7)    |
| src/libraries/Multicall.sol                        | 100.00% (10/10)    | 100.00% (16/16)    | 100.00% (0/0)    | 100.00% (1/1)    |
| src/libraries/OfferLibrary.sol                     | 100.00% (10/10)    | 100.00% (22/22)    | 100.00% (4/4)    | 100.00% (6/6)    |
| src/libraries/RiskLibrary.sol                      | 92.86% (26/28)     | 96.00% (48/50)     | 83.33% (10/12)   | 100.00% (10/10)  |
| src/libraries/YieldCurveLibrary.sol                | 94.12% (32/34)     | 96.49% (55/57)     | 75.00% (15/20)   | 100.00% (4/4)    |
| src/libraries/actions/BuyCreditLimit.sol           | 100.00% (10/10)    | 100.00% (11/11)    | 100.00% (6/6)    | 100.00% (2/2)    |
| src/libraries/actions/BuyCreditMarket.sol          | 100.00% (50/50)    | 100.00% (57/57)    | 90.91% (20/22)   | 100.00% (2/2)    |
| src/libraries/actions/Claim.sol                    | 100.00% (11/11)    | 100.00% (16/16)    | 100.00% (4/4)    | 100.00% (2/2)    |
| src/libraries/actions/Compensate.sol               | 100.00% (45/45)    | 100.00% (53/53)    | 86.36% (19/22)   | 100.00% (2/2)    |
| src/libraries/actions/Deposit.sol                  | 100.00% (22/22)    | 100.00% (28/28)    | 92.86% (13/14)   | 100.00% (2/2)    |
| src/libraries/actions/Initialize.sol               | 100.00% (66/66)    | 100.00% (74/74)    | 93.75% (30/32)   | 100.00% (11/11)  |
| src/libraries/actions/Liquidate.sol                | 100.00% (27/27)    | 100.00% (36/36)    | 83.33% (5/6)     | 100.00% (3/3)    |
| src/libraries/actions/LiquidateWithReplacement.sol | 100.00% (32/32)    | 100.00% (41/41)    | 100.00% (10/10)  | 100.00% (3/3)    |
| src/libraries/actions/Repay.sol                    | 100.00% (7/7)      | 100.00% (9/9)      | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/actions/SelfLiquidate.sol            | 100.00% (14/14)    | 100.00% (20/20)    | 66.67% (4/6)     | 100.00% (2/2)    |
| src/libraries/actions/SellCreditLimit.sol          | 100.00% (5/5)      | 100.00% (6/6)      | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/actions/SellCreditMarket.sol         | 100.00% (47/47)    | 100.00% (54/54)    | 92.31% (24/26)   | 100.00% (2/2)    |
| src/libraries/actions/SetUserConfiguration.sol     | 100.00% (14/14)    | 100.00% (21/21)    | 50.00% (2/4)     | 100.00% (2/2)    |
| src/libraries/actions/UpdateConfig.sol             | 100.00% (46/46)    | 100.00% (54/54)    | 100.00% (36/36)  | 100.00% (5/5)    |
| src/libraries/actions/Withdraw.sol                 | 100.00% (16/16)    | 100.00% (21/21)    | 75.00% (9/12)    | 100.00% (2/2)    |
| src/oracle/PriceFeed.sol                           | 95.65% (22/23)     | 97.50% (39/40)     | 87.50% (14/16)   | 100.00% (3/3)    |
| src/token/NonTransferrableScaledToken.sol          | 80.95% (17/21)     | 70.59% (24/34)     | 0.00% (0/2)      | 75.00% (9/12)    |
| src/token/NonTransferrableToken.sol                | 90.91% (10/11)     | 92.31% (12/13)     | 50.00% (1/2)     | 100.00% (8/8)    |

### Tests per file

```markdown
┌─────────────────────────────┬────────┐
│           (index)           │ Values │
├─────────────────────────────┼────────┤
│       BuyCreditLimit        │   4    │
│       BuyCreditMarket       │   10   │
│            Claim            │   10   │
│         Compensate          │   15   │
│       CryticToFoundry       │   20   │
│           Deposit           │   5    │
│         Initialize          │   4    │
│  LiquidateWithReplacement   │   6    │
│          Liquidate          │   10   │
│            Math             │   9    │
│          Multicall          │   7    │
│ NonTransferrableScaledToken │   4    │
│    NonTransferrableToken    │   7    │
│        OfferLibrary         │   1    │
│            Pause            │   2    │
│          PriceFeed          │   7    │
│            Repay            │   7    │
│        SelfLiquidate        │   10   │
│       SellCreditLimit       │   5    │
│      SellCreditMarket       │   12   │
│    SetUserConfiguration     │   3    │
│          SizeView           │   5    │
│        UpdateConfig         │   7    │
│           Upgrade           │   2    │
│          Withdraw           │   8    │
│         YieldCurve          │   14   │
└─────────────────────────────┴────────┘
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

- [`Math.binarySearch`](./test/libraries/Math.t.sol)

Run Halmos with

```bash
for i in {0..5}; do halmos --loop $i; done
```

## Known limitations

- The protocol currently supports only a single market (USDC/ETH for borrow/collateral tokens)
- The protocol does not support rebasing/fee-on-transfer tokens
- The protocol does not support tokens with different decimals than the current market
- The protocol only supports tokens compliant with the IERC20Metadata interface
- The protocol only supports pre-vetted tokens
- The protocol owner, KEEPER_ROLE, PAUSER_ROLE, and BORROW_RATE_UPDATER_ROLE are trusted
- The protocol does not have any fallback oracles.
- Price feeds must be redeployed and updated in case any Chainlink configuration changes (stale price timeouts, decimals, etc)
- In case Chainlink reports a wrong price, the protocol state cannot be guaranteed. This may cause incorrect liquidations, among other issues
- In case the protocol is paused, the price of the collateral may change during the unpause event. This may cause unforseen liquidations, among other issues
- It is not possible to pause individual functions. Nevertheless, BORROW_RATE_UPDATER_ROLE and admin functions are enabled even if the protocol is paused
- Users blacklisted by underlying tokens (e.g. USDC) may be unable to withdraw
- If the Variable Pool (Aave v3) fails to `supply` or `withdraw` for any reason, such as supply caps, Size's `deposit` and `withdraw` may be prevented
- Centralization risk related to integrations (USDC, Aave v3, Chainlink) are out of scope
- The Variable Pool Borrow Rate feed is trusted and users of rate hook adopt oracle risk of buying/selling credit at unsatisfactory prices
- The insurance fund (out of scope for this project) may not be able to make all lenders whole, maybe unfair, and may be manipulated
- LiquidateWithReplacement might not be available for the big enough debt positions
- All issues acknowledged on previous audits and automated findings

## Deployment

```bash
source .env
CHAIN_NAME=$CHAIN_NAME DEPLOYER_ADDRESS=$DEPLOYER_ADDRESS yarn deploy-sepolia-mocks --broadcast
```
