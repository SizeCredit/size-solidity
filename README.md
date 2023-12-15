# size-v2-solidity

Size V2 Solidity

## Coverage

<!-- BEGIN_COVERAGE -->
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
- the borrower debt is reduced in: repayment, standard liquidation, liquidation with replacement, self liquidation, borrower exit
- you can exit a SOL (??)

References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>

## TODOs

- lendAsLimitOrder TESTS
- selfLiquidate TESTS
- borrowerExit IMPL + TESTS
- test_Experiments_testBorrowerExit1
- convert experiments into fuzz tests
- variable pool
- dust amount for loans
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
