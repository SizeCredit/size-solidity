# size-v2-solidity

Size V2 Solidity

## Coverage

<!-- BEGIN_COVERAGE -->
[33mWarning! "--ir-minimum" flag enables viaIR with minimum optimization, which can result in inaccurate source mappings.
Only use this flag as a workaround if you are experiencing "stack too deep" errors.
Note that "viaIR" is only available in Solidity 0.8.13 and above.
See more:
https://github.com/foundry-rs/foundry/issues/3357
[0m
installing solc version "0.8.20"
Successfully installed solc 0.8.20
Compiling 114 files with 0.8.20
Solc 0.8.20 finished in 89.41s
Compiler run [32msuccessful![0m
Analysing contracts...
Running tests...
| File                                          | % Lines          | % Statements     | % Branches       | % Funcs         |
|-----------------------------------------------|------------------|------------------|------------------|-----------------|
| src/Size.sol                                  | 82.14% (23/28)   | 82.14% (23/28)   | 100.00% (0/0)    | 91.67% (11/12)  |
| src/SizeView.sol                              | 100.00% (18/18)  | 100.00% (28/28)  | 100.00% (0/0)    | 100.00% (16/16) |
| src/libraries/LoanLibrary.sol                 | 95.65% (22/23)   | 97.14% (34/35)   | 87.50% (7/8)     | 100.00% (9/9)   |
| src/libraries/MathLibrary.sol                 | 100.00% (1/1)    | 100.00% (3/3)    | 100.00% (0/0)    | 100.00% (1/1)   |
| src/libraries/OfferLibrary.sol                | 91.67% (22/24)   | 91.11% (41/45)   | 75.00% (6/8)     | 80.00% (4/5)    |
| src/libraries/YieldCurveLibrary.sol           | 100.00% (5/5)    | 100.00% (7/7)    | 100.00% (0/0)    | 100.00% (1/1)   |
| src/libraries/actions/BorrowAsLimitOrder.sol  | 100.00% (8/8)    | 100.00% (10/10)  | 100.00% (6/6)    | 100.00% (2/2)   |
| src/libraries/actions/BorrowAsMarketOrder.sol | 98.15% (53/54)   | 98.51% (66/67)   | 80.00% (16/20)   | 100.00% (4/4)   |
| src/libraries/actions/Claim.sol               | 100.00% (9/9)    | 100.00% (10/10)  | 75.00% (3/4)     | 100.00% (2/2)   |
| src/libraries/actions/Deposit.sol             | 100.00% (10/10)  | 100.00% (17/17)  | 100.00% (4/4)    | 100.00% (2/2)   |
| src/libraries/actions/Exit.sol                | 89.47% (34/38)   | 91.67% (44/48)   | 66.67% (12/18)   | 100.00% (2/2)   |
| src/libraries/actions/Initialize.sol          | 95.45% (42/44)   | 81.48% (44/54)   | 96.67% (29/30)   | 100.00% (2/2)   |
| src/libraries/actions/LendAsLimitOrder.sol    | 100.00% (14/14)  | 100.00% (17/17)  | 91.67% (11/12)   | 100.00% (2/2)   |
| src/libraries/actions/LendAsMarketOrder.sol   | 0.00% (0/21)     | 0.00% (0/23)     | 0.00% (0/8)      | 0.00% (0/2)     |
| src/libraries/actions/LiquidateLoan.sol       | 90.91% (40/44)   | 93.85% (61/65)   | 78.57% (11/14)   | 100.00% (6/6)   |
| src/libraries/actions/Repay.sol               | 100.00% (14/14)  | 100.00% (14/14)  | 75.00% (6/8)     | 100.00% (2/2)   |
| src/libraries/actions/Withdraw.sol            | 100.00% (10/10)  | 100.00% (17/17)  | 100.00% (4/4)    | 100.00% (2/2)   |
| src/oracle/PriceFeed.sol                      | 100.00% (12/12)  | 100.00% (21/21)  | 100.00% (8/8)    | 100.00% (3/3)   |
| src/token/NonTransferrableToken.sol           | 100.00% (8/8)    | 100.00% (9/9)    | 100.00% (0/0)    | 100.00% (6/6)   |
<!-- END_COVERAGE -->

## Test

```bash
forge test --match-test test_experiment_dynamic -vv --via-ir --ffi --watch
```

## Invariants

| Property | Category    | Description                                                                              |
| -------- | ----------- | ---------------------------------------------------------------------------------------- |
| C-01     | Collateral  | Locked cash in the user account can't be withdrawn                                       |
| C-02     | Collateral  | The sum of all free and locked collateral is equal to the token balance of the orderbook |
| C-03     | Collateral  | A user cannot make an operation that leaves them underwater |
| L-01     | Liquidation | A borrower is eligible to liquidation if it is underwater or if the due date has reached |

- SOL(loanId).FV <= FOL(loanId).FV
- SUM(SOL(loanId).FV) == FOL(loanId).FV
- fol.FV = SUM(Loan.FV - Loan.ExitedAmount) for all SOLs, FOL
- loan.amountFVExited <= self.FV
- loan.FV == 0 && isFOL(loan) <==> loan.repaid
- loan.repaid ==> !isFOL(loan)
- upon repayment, the money is locked from the lender until due date, and the protocol earns yield meanwhile
- cash.free + cash.locked ?= deposits
- creating a FOL/SOL decreases a loanOffer maxAmount
- repay should never DoS due to underflow
- only FOLs can be claimed(??)
- a loan is liquidatable if a user is liquidatable (CR < LCR)
- Taking loan with only virtual collateral does not decrease the borrower CR
- Taking loan with real collateral decreases the borrower CR

References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>

## TODOs

- 100% coverage
- dust amount for loans
- add experiments as tests
- should withdraw update BorrowOffer? if (user.borrowAsset.free < user.loanOffer.maxAmount) user.loanOffer.maxAmount = user.borrowAsset.free;
- test events
- refactor tests following Sablier v2 naming conventions: `test_Foo`, `testFuzz_Foo`, `test_RevertWhen_Foo`, `testFuzz_RevertWhen_Foo`, `testFork_...`
- test libraries (OfferLibrary.getRate, etc)

## Later

- create helper contracts for liquidation in 1 step (deposit -> liquidate -> withdraw)
- natspec
- multi-erc20 tokens with different CR per tokens

## Audit remarks

- Check rounding direction of `mulDiv`

## Known limitations

- Protocol does not support rebasing tokens
- Protocol does not support fee-on-transfer tokens
- Protocol does not support tokens with more than 18 decimals
- All features except deposits/withdrawals are paused in case Chainlink oracles are stale
- Price feeds must be redeployed and updated on the `Size` smart contract in case any chainlink configuration changes (stale price, decimals)
