# size-v2-solidity

Size V2 Solidity

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
| src/libraries/fixed/actions/BorrowerExit.sol                      | 95.83% (23/24)    | 96.77% (30/31)     | 75.00% (6/8)     | 100.00% (2/2)    |
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
| src/libraries/general/actions/Initialize.sol                      | 98.08% (51/52)    | 98.31% (58/59)     | 96.15% (25/26)   | 100.00% (8/8)    |
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

## Invariants

- creating a FOL/SOL decreases a offer maxAmount
- you can exit a SOL
- liquidation with replacement does not increase the total system debt
- Taking loan with only virtual collateral does not decrease the borrower CR
- Taking loan with real collateral decreases the borrower CR
- The user cannot withdraw more than their deposits
- If isLiquidatable && liquidator has enough cash, the liquidation should always succeed (requires adding more checks to isLiquidatable)
- When a user self liquidates a SOL, it will improve the collateralization ratio of other SOLs. This is because self liquidating decreases the FOL's face value, so it decreases all SOL's debt
- No loan (FOL/SOL) can ever become a dust loan
- the protocol vault is always solvent (how to check for that?)
- $Credit(i) = FV(i) - \sum\limits_{j~where~Exiter(j)=i}{FV(j)}$ /// For example, when a loan i exits to another j, Exiter(j) = i. This isn't tracked anywhere on-chain, as it's not necessary under the correct accounting conditions, as the loan structure only tracks the folId, not the "originator". But the originator can also be a SOL, when a SOL exits to another SOL. But it can be emitted, which may be used for off-chain metrics, so I guess I'll add that to the event. Also, when doing fuzzing/formal verification, we can also add "ghost variables" to track the "originator", so no need to add it to the protocol, but this concept can be useful in assessing the correct behavior of the exit logic
- The VP utilization ratio should never be greater than 1
- the collateral ratio of a loan should always be >= than before, after a partial liquidation. We can apply the same invariant in the fixed rate OB for operations like self liquidations and credit debt compensation

## TODO if there's time

- mint szWETH to user vault

## TODO before audit

- gas optimize the 80/20 rule
- add tests for fixed borrows with dueDate now
- review all input validation functions
- add natspec

## TODO before mainnet

- Do the Aave fork, document and automate mitigations
- Learn how to do liquidations in our Aave fork
- add aave tests
- test events
- monitoring
- incident response plan

## Gas optimizations

- separate Loan struct
- refactor tests following Sablier v2 naming conventions: `test_Foo`, `testFuzz_Foo`, `test_RevertWhen_Foo`, `testFuzz_RevertWhen_Foo`, `testFork_...`
- use solady for tokens or other simple primitives

## Notes for auditors

- // @audit Check rounding direction of `FixedPointMath.mulDiv*`
- // @audit Check if borrower == lender == liquidator may cause any issues

## Questions

- Check how Aave does insurance

## Known limitations

- Protocol does not support rebasing tokens
- Protocol does not support fee-on-transfer tokens
- Protocol does not support tokens with more than 18 decimals
- Protocol only supports tokens compliant with the IERC20Metadata interface
- Protocol only supports pre-vetted tokens
- All features except deposits/withdrawals are paused in case Chainlink oracles are stale
- In cas Chainlink reports a wrong price, the protocol state cannot be guaranteed (invalid liquidations, etc)
- Price feeds must be redeployed and updated on the `Size` smart contract in case any chainlink configuration changes (stale price, decimals)
