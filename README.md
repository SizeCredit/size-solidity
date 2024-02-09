# size-v2-solidity

Size V2 Solidity

![Size](./size.jpeg)

Size is an order book based fixed rate lending protocol with an integrated variable pool.

Initial pairs supported:

- ETH: Collateral token
- USDC: Borrow/Lend token

Target networks:

- Ethereum mainnet
- Base

## Documentation

### Accounting and Protocol Design

- [Hackmd](https://hackmd.io/DEUtX6xLQTuWzawpkrd_Sw?view)

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

The `Multicall` pattern is also available to allow users to perform a sequence of multiple actions, such as depositing borrow tokens, liquidating an underwater borrower, and withdrawing all liquidated collateral.

Additional safety features were employed, such as different levels of Access Control (ADMIN, PAUSER_ROLE, KEEPER_ROLE), and Pause.

#### Tokens

In order to address donation and reentrancy attacks, the following measures were adopted:

- No usage of native ether, only wrapped ether (WETH)
- Underlying borrow and collateral tokens, such as USDC and WETH, are converted 1:1 into protocol tokens via `deposit`, which mints `aszUSDC` and `szWETH`, and received back via `withdraw`, which burns protocol tokens 1:1 in exchange of the underlying tokens.

#### Maths

All mathematical operations are implemented with explicit rounding (`mulDivUp` or `mulDivDown`) using Solady's [FixedPointMathLib](https://github.com/Vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol).

Decimal amounts are preserved until a conversion is necessary, and performed via the `ConversionLibrary`:

- USDC/aszUSDC: 6 decimals
- szDebt: 6 decimals (same as borrow token)
- WETH/szETH: 18 decimals
- PriceFeed (ETH/USDC): 18 decimals
- MarketBorrowRateFeed (USDC): 18 decimals

All percentages are expressed in 18 decimals. For example, a 150% liquidation collateral ratio is represented as 1500000000000000000.

#### Variable Pool

In order to interact with Size's Variable Pool (Aave v3 fork), a proxy pattern is employed, which creates user Vault proxies using OpenZeppelin Clone's library to deploy copies on demand. This way, each address can have an individual health factor on Size's Variable Pool (Aave v3 fork). The `Vault` contract is owned by the `Size` contract, which can perform arbitrary calls on behalf of the user. For example, when a `deposit` is performed on `Size`, it creates a `Vault`, if needed, which then executes a `supply` on Size's Variable Pool (Aave v3 fork). This way, all deposited `USDC` can be lent out through variable rates until a fixed-rate loan is matched and created on the orderbook.

When an account executes `supply` into Size's Variable Pool (Aave v3 fork), the `aszUSDC` token is minted 1:1. This is an instance of `AToken`, an interest-bearing rebasing token that represents users' USDC available for variable-rate loans, which grows according to a variable interest rate equation.

#### Oracles

##### Price Feed

Two Chainlink aggregators are used to fetch the ETH/USDC rate. A conversion from ETH/USD and USDC/USD is performed and the result is rounded down to 18 decimals. For example, a spot price of 2,426.59 ETH/USDC is represented as 2426590000000000000000.

##### Market Borrow Rate Feed

In order to approximate the current market average value of USDC variable borrow rates, we use Aave v3, and convert it to 18 decimals. For example, a rate of 2.49% on Aave v3 is represented as 24900000000000000.

Note that this rate is extracted from Aave v3 itself, not from Size's Variable Pool (Aave v3 fork). Although these two pools share the same code and interfaces, we believe Aave v3 is a better proxy for the real market rate, and less prone to market manipulation attacks.

In the future, integrations with other protocols will be implemented in order to have a more realistic global average.

## Test

```bash
forge install
forge test
```

## Coverage

<!-- BEGIN_COVERAGE -->
### FIles

| File                                                         | % Lines           | % Statements       | % Branches       | % Funcs          |
|--------------------------------------------------------------|-------------------|--------------------|------------------|------------------|
| src/Size.sol                                                 | 100.00% (47/47)   | 100.00% (47/47)    | 100.00% (0/0)    | 100.00% (16/16)  |
| src/SizeView.sol                                             | 93.75% (30/32)    | 94.23% (49/52)     | 100.00% (0/0)    | 90.91% (20/22)   |
| src/libraries/ConversionLibrary.sol                          | 25.00% (1/4)      | 30.00% (3/10)      | 100.00% (0/0)    | 25.00% (1/4)     |
| src/libraries/Math.sol                                       | 89.47% (17/19)    | 90.00% (27/30)     | 83.33% (5/6)     | 87.50% (7/8)     |
| src/libraries/fixed/AccountingLibrary.sol                    | 64.00% (16/25)    | 63.33% (19/30)     | 100.00% (0/0)    | 75.00% (3/4)     |
| src/libraries/fixed/CapsLibrary.sol                          | 100.00% (6/6)     | 100.00% (9/9)      | 50.00% (3/6)     | 100.00% (3/3)    |
| src/libraries/fixed/CollateralLibrary.sol                    | 100.00% (6/6)     | 100.00% (8/8)      | 100.00% (0/0)    | 100.00% (2/2)    |
| src/libraries/fixed/LoanLibrary.sol                          | 100.00% (36/36)   | 98.48% (65/66)     | 91.67% (11/12)   | 100.00% (13/13)  |
| src/libraries/fixed/OfferLibrary.sol                         | 0.00% (0/5)       | 0.00% (0/14)       | 100.00% (0/0)    | 0.00% (0/4)      |
| src/libraries/fixed/RiskLibrary.sol                          | 84.00% (21/25)    | 85.71% (36/42)     | 80.00% (8/10)    | 88.89% (8/9)     |
| src/libraries/fixed/YieldCurveLibrary.sol                    | 36.00% (9/25)     | 37.78% (17/45)     | 42.86% (6/14)    | 33.33% (1/3)     |
| src/libraries/fixed/actions/BorrowAsLimitOrder.sol           | 100.00% (3/3)     | 100.00% (3/3)      | 100.00% (0/0)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/BorrowAsMarketOrder.sol          | 98.00% (49/50)    | 98.31% (58/59)     | 95.00% (19/20)   | 100.00% (4/4)    |
| src/libraries/fixed/actions/BorrowerExit.sol                 | 91.67% (22/24)    | 93.55% (29/31)     | 62.50% (5/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Claim.sol                        | 100.00% (10/10)   | 100.00% (12/12)    | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/Compensate.sol                   | 100.00% (26/26)   | 100.00% (32/32)    | 93.75% (15/16)   | 100.00% (2/2)    |
| src/libraries/fixed/actions/Deposit.sol                      | 90.91% (10/11)    | 93.75% (15/16)     | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsLimitOrder.sol             | 85.71% (6/7)      | 85.71% (6/7)       | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsMarketOrder.sol            | 95.00% (19/20)    | 95.45% (21/22)     | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LiquidateLoan.sol                | 97.50% (39/40)    | 97.87% (46/47)     | 64.29% (9/14)    | 100.00% (4/4)    |
| src/libraries/fixed/actions/LiquidateLoanWithReplacement.sol | 100.00% (24/24)   | 100.00% (30/30)    | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Repay.sol                        | 100.00% (16/16)   | 100.00% (19/19)    | 87.50% (7/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/SelfLiquidateLoan.sol            | 100.00% (21/21)   | 100.00% (26/26)    | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Withdraw.sol                     | 100.00% (15/15)   | 100.00% (22/22)    | 75.00% (9/12)    | 100.00% (2/2)    |
| src/libraries/general/actions/Initialize.sol                 | 100.00% (58/58)   | 100.00% (66/66)    | 100.00% (28/28)  | 100.00% (9/9)    |
| src/libraries/general/actions/UpdateConfig.sol               | 72.97% (27/37)    | 75.00% (30/40)     | 66.67% (20/30)   | 80.00% (4/5)     |
| src/libraries/variable/VariableLibrary.sol                   | 100.00% (46/46)   | 100.00% (66/66)    | 100.00% (4/4)    | 87.50% (7/8)     |
| src/oracle/MarketBorrowRateFeed.sol                          | 0.00% (0/1)       | 0.00% (0/2)        | 100.00% (0/0)    | 0.00% (0/1)      |
| src/oracle/PriceFeed.sol                                     | 100.00% (12/12)   | 100.00% (21/21)    | 100.00% (8/8)    | 100.00% (3/3)    |
| src/proxy/Vault.sol                                          | 57.14% (12/21)    | 60.00% (15/25)     | 33.33% (4/12)    | 75.00% (3/4)     |
| src/token/NonTransferrableToken.sol                          | 100.00% (9/9)     | 100.00% (10/10)    | 100.00% (0/0)    | 100.00% (7/7)    |

### Scenarios

```markdown
┌──────────────────────────────┬────────┐
│           (index)            │ Values │
├──────────────────────────────┼────────┤
│      BorrowAsLimitOrder      │   5    │
│     BorrowAsMarketOrder      │   13   │
│         BorrowerExit         │   4    │
│            Claim             │   8    │
│          Compensate          │   4    │
│      ConversionLibrary       │   6    │
│       CryticToFoundry        │   8    │
│           Deposit            │   3    │
│         Experiments          │   12   │
│          Initialize          │   4    │
│       LendAsLimitOrder       │   2    │
│      LendAsMarketOrder       │   6    │
│ LiquidateLoanWithReplacement │   5    │
│        LiquidateLoan         │   7    │
│             Math             │   5    │
│          Multicall           │   3    │
│    NonTransferrableToken     │   7    │
│          PriceFeed           │   8    │
│            Repay             │   4    │
│      SelfLiquidateLoan       │   6    │
│         UpdateConfig         │   3    │
│           Upgrade            │   2    │
│           Withdraw           │   8    │
│          YieldCurve          │   13   │
└──────────────────────────────┴────────┘
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
- When a user self liquidates a SOL, it will improve the collateralization ratio of other SOLs. This is because self liquidating decreases the FOL's faceValue, so it decreases all SOL's debt

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

## Areas of concern

- A rounding issue as a result of the FOL's `faceValue` calculation may result in the borrower debt being 1 more when the lender picks their borrow offer with `lendAsMarketOrder`, passing `exactAmountIn` equals `false`. In this case, to calculate the `issuanceValue`, a `mulDivUp` is performed, so that the borrower, being the passive party, receives _more_ aszUSDC tokens. The issue is that the `faceValue` calculation is also rounded up in `LoanLibrary`, as it represents a users' debt. In summary, the borrower receives rounding up in the present value, but pays rounding up in future cash flow. Exploits arising from this issue are welcome.
- Exploits arising from notes marked with `// @audit` on the codebase are welcome
