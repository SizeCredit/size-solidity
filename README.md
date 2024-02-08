# size-v2-solidity

Size V2 Solidity

## Setup

## Test

```bash
forge install
forge test
```

## Coverage

<!-- BEGIN_COVERAGE -->
### FIles

| File                                                              | % Lines           | % Statements       | % Branches       | % Funcs          |
|-------------------------------------------------------------------|-------------------|--------------------|------------------|------------------|
| src/Size.sol                                                      | 100.00% (44/44)   | 100.00% (44/44)    | 100.00% (0/0)    | 100.00% (16/16)  |
| src/SizeView.sol                                                  | 94.44% (17/18)    | 96.67% (29/30)     | 100.00% (0/0)    | 94.12% (16/17)   |
| src/libraries/ConversionLibrary.sol                               | 25.00% (1/4)      | 30.00% (3/10)      | 100.00% (0/0)    | 25.00% (1/4)     |
| src/libraries/Math.sol                                            | 94.74% (18/19)    | 96.67% (29/30)     | 83.33% (5/6)     | 100.00% (7/7)    |
| src/libraries/fixed/CapsLibrary.sol                               | 100.00% (6/6)     | 100.00% (9/9)      | 50.00% (3/6)     | 100.00% (3/3)    |
| src/libraries/fixed/CollateralLibrary.sol                         | 100.00% (6/6)     | 100.00% (8/8)      | 100.00% (0/0)    | 100.00% (2/2)    |
| src/libraries/fixed/FixedLibrary.sol                              | 100.00% (68/68)   | 99.07% (106/107)   | 95.00% (19/20)   | 83.33% (15/18)   |
| src/libraries/fixed/FixedLoanLibrary.sol                          | 0.00% (0/2)       | 0.00% (0/4)        | 100.00% (0/0)    | 0.00% (0/2)      |
| src/libraries/fixed/OfferLibrary.sol                              | 0.00% (0/5)       | 0.00% (0/14)       | 100.00% (0/0)    | 0.00% (0/4)      |
| src/libraries/fixed/YieldCurveLibrary.sol                         | 36.00% (9/25)     | 37.78% (17/45)     | 42.86% (6/14)    | 33.33% (1/3)     |
| src/libraries/fixed/actions/BorrowAsLimitOrder.sol                | 100.00% (3/3)     | 100.00% (3/3)      | 100.00% (0/0)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/BorrowAsMarketOrder.sol               | 100.00% (53/53)   | 100.00% (66/66)    | 95.00% (19/20)   | 100.00% (4/4)    |
| src/libraries/fixed/actions/BorrowerExit.sol                      | 96.00% (24/25)    | 96.88% (31/32)     | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Claim.sol                             | 100.00% (10/10)   | 100.00% (12/12)    | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/Compensate.sol                        | 100.00% (21/21)   | 100.00% (26/26)    | 100.00% (12/12)  | 100.00% (2/2)    |
| src/libraries/fixed/actions/Deposit.sol                           | 90.91% (10/11)    | 93.75% (15/16)     | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsLimitOrder.sol                  | 85.71% (6/7)      | 85.71% (6/7)       | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LendAsMarketOrder.sol                 | 96.00% (24/25)    | 96.15% (25/26)     | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/LiquidateFixedLoan.sol                | 97.56% (40/41)    | 98.00% (49/50)     | 64.29% (9/14)    | 100.00% (4/4)    |
| src/libraries/fixed/actions/LiquidateFixedLoanWithReplacement.sol | 100.00% (23/23)   | 100.00% (27/27)    | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Repay.sol                             | 100.00% (19/19)   | 100.00% (23/23)    | 80.00% (8/10)    | 100.00% (2/2)    |
| src/libraries/fixed/actions/SelfLiquidateFixedLoan.sol            | 100.00% (18/18)   | 100.00% (23/23)    | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/fixed/actions/Withdraw.sol                          | 100.00% (15/15)   | 100.00% (22/22)    | 75.00% (9/12)    | 100.00% (2/2)    |
| src/libraries/general/actions/Initialize.sol                      | 98.15% (53/54)    | 98.36% (60/61)     | 96.15% (25/26)   | 100.00% (8/8)    |
| src/libraries/general/actions/UpdateConfig.sol                    | 100.00% (10/10)   | 100.00% (10/10)    | 100.00% (8/8)    | 100.00% (2/2)    |
| src/libraries/variable/VariableLibrary.sol                        | 100.00% (46/46)   | 100.00% (66/66)    | 100.00% (4/4)    | 87.50% (7/8)     |
| src/oracle/MarketBorrowRateFeed.sol                               | 0.00% (0/1)       | 0.00% (0/2)        | 100.00% (0/0)    | 0.00% (0/1)      |
| src/oracle/PriceFeed.sol                                          | 100.00% (12/12)   | 100.00% (21/21)    | 100.00% (8/8)    | 100.00% (3/3)    |
| src/proxy/UserProxy.sol                                           | 57.14% (12/21)    | 60.00% (15/25)     | 33.33% (4/12)    | 75.00% (3/4)     |
| src/proxy/Vault.sol                                               | 0.00% (0/21)      | 0.00% (0/25)       | 0.00% (0/12)     | 0.00% (0/4)      |
| src/token/NonTransferrableToken.sol                               | 100.00% (9/9)     | 100.00% (10/10)    | 100.00% (0/0)    | 100.00% (7/7)    |

### Scenarios

```markdown
┌───────────────────────────────────┬────────┐
│              (index)              │ Values │
├───────────────────────────────────┼────────┤
│              BORROW               │   1    │
│        BorrowAsLimitOrder         │   5    │
│        BorrowAsMarketOrder        │   14   │
│           BorrowerExit            │   4    │
│               Claim               │   8    │
│            Compensate             │   6    │
│         ConversionLibrary         │   6    │
│              DEPOSIT              │   1    │
│              Deposit              │   3    │
│            Experiments            │   10   │
│            Initialize             │   3    │
│               LOAN                │   2    │
│         LendAsLimitOrder          │   2    │
│         LendAsMarketOrder         │   6    │
│ LiquidateFixedLoanWithReplacement │   5    │
│        LiquidateFixedLoan         │   7    │
│               Math                │   5    │
│             Multicall             │   3    │
│       NonTransferrableToken       │   7    │
│             PriceFeed             │   8    │
│               REPAY               │   2    │
│               Repay               │   9    │
│      SelfLiquidateFixedLoan       │   6    │
│              TOKENS               │   1    │
│           UpdateConfig            │   3    │
│              Upgrade              │   2    │
│             Withdraw              │   8    │
│            YieldCurve             │   13   │
└───────────────────────────────────┴────────┘
```
<!-- END_COVERAGE -->

## Documentation

- decimals:
  - USDC/aszUSDC: 6
  - WETH/szETH: 18
  - szDebt: 6
  - PriceFeed: 18

## Deployment

```bash
npm run deploy-sepolia
```

## Invariants implemented

- Check [`Properties.sol`](./test/invariants/Properties.sol)

## Invariants to be implemented

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
