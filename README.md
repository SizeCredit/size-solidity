# size-v2-solidity

Size V2 Solidity

## Coverage

<!-- BEGIN_COVERAGE -->
| File                                                   | % Lines          | % Statements     | % Branches       | % Funcs         |
|--------------------------------------------------------|------------------|------------------|------------------|-----------------|
| src/Size.sol                                           | 94.44% (34/36)   | 94.44% (34/36)   | 100.00% (0/0)    | 100.00% (15/15) |
| src/SizeView.sol                                       | 100.00% (20/20)  | 100.00% (29/29)  | 100.00% (0/0)    | 100.00% (18/18) |
| src/libraries/LoanLibrary.sol                          | 95.45% (21/22)   | 96.88% (31/32)   | 87.50% (7/8)     | 100.00% (8/8)   |
| src/libraries/MathLibrary.sol                          | 100.00% (1/1)    | 100.00% (3/3)    | 100.00% (0/0)    | 100.00% (1/1)   |
| src/libraries/OfferLibrary.sol                         | 95.83% (23/24)   | 97.78% (44/45)   | 87.50% (7/8)     | 100.00% (5/5)   |
| src/libraries/YieldCurveLibrary.sol                    | 100.00% (5/5)    | 100.00% (7/7)    | 100.00% (0/0)    | 100.00% (1/1)   |
| src/libraries/actions/BorrowAsLimitOrder.sol           | 100.00% (8/8)    | 100.00% (10/10)  | 100.00% (6/6)    | 100.00% (2/2)   |
| src/libraries/actions/BorrowAsMarketOrder.sol          | 98.18% (54/55)   | 98.53% (67/68)   | 81.82% (18/22)   | 100.00% (4/4)   |
| src/libraries/actions/BorrowerExit.sol                 | 96.30% (26/27)   | 97.06% (33/34)   | 70.00% (7/10)    | 100.00% (2/2)   |
| src/libraries/actions/Claim.sol                        | 100.00% (9/9)    | 100.00% (10/10)  | 75.00% (3/4)     | 100.00% (2/2)   |
| src/libraries/actions/Deposit.sol                      | 100.00% (10/10)  | 100.00% (17/17)  | 100.00% (4/4)    | 100.00% (2/2)   |
| src/libraries/actions/Initialize.sol                   | 95.24% (40/42)   | 80.77% (42/52)   | 96.67% (29/30)   | 100.00% (2/2)   |
| src/libraries/actions/LendAsLimitOrder.sol             | 100.00% (14/14)  | 100.00% (17/17)  | 91.67% (11/12)   | 100.00% (2/2)   |
| src/libraries/actions/LendAsMarketOrder.sol            | 26.09% (6/23)    | 35.71% (10/28)   | 37.50% (3/8)     | 50.00% (1/2)    |
| src/libraries/actions/LenderExit.sol                   | 89.47% (34/38)   | 91.49% (43/47)   | 66.67% (12/18)   | 100.00% (2/2)   |
| src/libraries/actions/LiquidateLoan.sol                | 97.83% (45/46)   | 98.36% (60/61)   | 85.71% (12/14)   | 100.00% (6/6)   |
| src/libraries/actions/LiquidateLoanWithReplacement.sol | 100.00% (22/22)  | 100.00% (25/25)  | 50.00% (2/4)     | 100.00% (2/2)   |
| src/libraries/actions/Repay.sol                        | 100.00% (14/14)  | 100.00% (14/14)  | 75.00% (6/8)     | 100.00% (2/2)   |
| src/libraries/actions/SelfLiquidateLoan.sol            | 100.00% (24/24)  | 100.00% (27/27)  | 70.00% (7/10)    | 100.00% (2/2)   |
| src/libraries/actions/Withdraw.sol                     | 100.00% (10/10)  | 100.00% (17/17)  | 100.00% (4/4)    | 100.00% (2/2)   |
| src/oracle/PriceFeed.sol                               | 100.00% (12/12)  | 100.00% (21/21)  | 100.00% (8/8)    | 100.00% (3/3)   |
| src/token/NonTransferrableToken.sol                    | 100.00% (8/8)    | 100.00% (9/9)    | 100.00% (0/0)    | 100.00% (6/6)   |
<!-- END_COVERAGE -->

## Test

```bash
forge test --match-test test_experiment_dynamic -vv --via-ir --ffi --watch
```

## Documentation

- Inside the protocol, all values are expressed in WAD (18 decimals), including price feed decimals and percentages

## Invariants

| Property | Category    | Description                                                                              |
| -------- | ----------- | ---------------------------------------------------------------------------------------- |
| C-01     | Collateral  | Locked cash in the user account can't be withdrawn                                       |
| C-02     | Collateral  | The sum of all free and locked collateral is equal to the token balance of the orderbook |
| C-03     | Collateral  | A user cannot make an operation that leaves them underwater |
| L-01     | Liquidation | A borrower is eligible to liquidation if it is underwater or if the due date has reached |

- SOL(loanId).FV <= FOL(loanId).FV
- SUM(SOL(loanId).FV) == FOL(loanId).FV
- FOL.amountFVExited = SUM(SOL.getCredit)
- fol.FV = SUM(Loan.FV - Loan.ExitedAmount) for all SOLs, FOL
- loan.amountFVExited <= self.FV
- loan.FV == 0 && isFOL(loan) <==> loan.repaid (incorrect)
- loan.repaid ==> !isFOL(loan)
- upon repayment, the money is locked from the lender until due date, and the protocol earns yield meanwhile
- cash.free + cash.locked ?= deposits
- creating a FOL/SOL decreases a loanOffer maxAmount
- repay should never DoS due to underflow
- only FOLs can be claimed(??)
- a loan is liquidatable if a user is liquidatable (CR < LCR)
- Taking loan with only virtual collateral does not decrease the borrower CR
- Taking loan with real collateral decreases the borrower CR
- the borrower debt is reduced in: repayment, standard liquidation, liquidation with replacement, self liquidation, borrower exit
- you can exit a SOL (??)
- if isLiquidatable && liquidator has enough cash, the liquidation should always succeed (requires adding more checks to isLiquidatable)

References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>

## TODOs

- convert experiments into fuzz tests
- variable pool
- dust amount for loans (creation & updating of FV)
- simplify Loan struct
- should withdraw update BorrowOffer? if (user.borrowAsset.free < user.loanOffer.maxAmount) user.loanOffer.maxAmount = user.borrowAsset.free;
- test events
- refactor tests following Sablier v2 naming conventions: `test_Foo`, `testFuzz_Foo`, `test_RevertWhen_Foo`, `testFuzz_RevertWhen_Foo`, `testFork_...`
- test libraries (OfferLibrary.getRate, etc)
- test liquidator profits
- test liquiadtion library collateralRate, etc, and others, for important decimals/etc, hardcoded values
- 100% coverage

## Later

- create helper contracts for liquidation in 1 step (deposit -> liquidate -> withdraw)
- natspec
- multi-erc20 tokens with different CR per tokens
- review all input validation functions
- review all valid output states (e.g. validateUserIsNotLiquidatable)

## Audit remarks

- Check rounding direction of `mulDiv`

## Known limitations

- Protocol does not support rebasing tokens
- Protocol does not support fee-on-transfer tokens
- Protocol does not support tokens with more than 18 decimals
- Protocol only supports tokens compliant with the IERC20Metadata interface
- Protocol only supports pre-vetted tokens
- All features except deposits/withdrawals are paused in case Chainlink oracles are stale
- In cas Chainlink reports a wrong price, the protocol state cannot be guaranteed (invalid liquidations, etc)
- Price feeds must be redeployed and updated on the `Size` smart contract in case any chainlink configuration changes (stale price, decimals)
