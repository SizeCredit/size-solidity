# size-v2-solidity

Size V2 Solidity

## Coverage

<!-- BEGIN_COVERAGE -->
| File                                                   | % Lines          | % Statements      | % Branches       | % Funcs          |
|--------------------------------------------------------|------------------|-------------------|------------------|------------------|
| script/BaseScript.sol                                  | 0.00% (0/24)     | 0.00% (0/33)      | 0.00% (0/2)      | 0.00% (0/4)      |
| script/Deploy.s.sol                                    | 0.00% (0/22)     | 0.00% (0/22)      | 100.00% (0/0)    | 0.00% (0/2)      |
| src/Size.sol                                           | 94.44% (34/36)   | 94.44% (34/36)    | 100.00% (0/0)    | 100.00% (15/15)  |
| src/SizeView.sol                                       | 100.00% (23/23)  | 100.00% (33/33)   | 100.00% (0/0)    | 100.00% (21/21)  |
| src/libraries/LoanLibrary.sol                          | 42.86% (3/7)     | 35.71% (5/14)     | 100.00% (0/0)    | 60.00% (3/5)     |
| src/libraries/MathLibrary.sol                          | 100.00% (1/1)    | 100.00% (3/3)     | 100.00% (0/0)    | 100.00% (1/1)    |
| src/libraries/OfferLibrary.sol                         | 95.83% (23/24)   | 97.78% (44/45)    | 87.50% (7/8)     | 100.00% (5/5)    |
| src/libraries/YieldCurveLibrary.sol                    | 100.00% (5/5)    | 100.00% (7/7)     | 100.00% (0/0)    | 100.00% (1/1)    |
| src/libraries/actions/BorrowAsLimitOrder.sol           | 100.00% (8/8)    | 100.00% (10/10)   | 100.00% (6/6)    | 100.00% (2/2)    |
| src/libraries/actions/BorrowAsMarketOrder.sol          | 100.00% (55/55)  | 100.00% (71/71)   | 86.36% (19/22)   | 100.00% (4/4)    |
| src/libraries/actions/BorrowerExit.sol                 | 96.30% (26/27)   | 97.06% (33/34)    | 70.00% (7/10)    | 100.00% (2/2)    |
| src/libraries/actions/Claim.sol                        | 100.00% (9/9)    | 100.00% (10/10)   | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/actions/Common.sol                       | 100.00% (44/44)  | 100.00% (65/65)   | 100.00% (16/16)  | 100.00% (13/13)  |
| src/libraries/actions/Deposit.sol                      | 100.00% (10/10)  | 100.00% (17/17)   | 100.00% (4/4)    | 100.00% (2/2)    |
| src/libraries/actions/Initialize.sol                   | 100.00% (45/45)  | 85.45% (47/55)    | 100.00% (32/32)  | 100.00% (2/2)    |
| src/libraries/actions/LendAsLimitOrder.sol             | 100.00% (14/14)  | 100.00% (17/17)   | 91.67% (11/12)   | 100.00% (2/2)    |
| src/libraries/actions/LendAsMarketOrder.sol            | 26.09% (6/23)    | 35.71% (10/28)    | 37.50% (3/8)     | 50.00% (1/2)     |
| src/libraries/actions/LiquidateLoan.sol                | 96.88% (31/32)   | 97.37% (37/38)    | 62.50% (5/8)     | 100.00% (2/2)    |
| src/libraries/actions/LiquidateLoanWithReplacement.sol | 100.00% (22/22)  | 100.00% (25/25)   | 50.00% (2/4)     | 100.00% (2/2)    |
| src/libraries/actions/MoveToVariablePool.sol           | 100.00% (13/13)  | 100.00% (16/16)   | 66.67% (4/6)     | 100.00% (2/2)    |
| src/libraries/actions/Repay.sol                        | 100.00% (14/14)  | 100.00% (14/14)   | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/actions/SelfLiquidateLoan.sol            | 100.00% (24/24)  | 100.00% (28/28)   | 70.00% (7/10)    | 100.00% (2/2)    |
| src/libraries/actions/Withdraw.sol                     | 100.00% (10/10)  | 100.00% (17/17)   | 100.00% (4/4)    | 100.00% (2/2)    |
| src/oracle/PriceFeed.sol                               | 100.00% (12/12)  | 100.00% (21/21)   | 100.00% (8/8)    | 100.00% (3/3)    |
| src/token/NonTransferrableToken.sol                    | 100.00% (8/8)    | 100.00% (9/9)     | 100.00% (0/0)    | 100.00% (6/6)    |
<!-- END_COVERAGE -->

## Test

```bash
forge test --match-test test_experiment_dynamic -vv --via-ir --ffi --watch
```

## Documentation

- Inside the protocol, all values are expressed in WAD (18 decimals), including price feed decimals and percentages

## Invariants

- SUM(SOL(loanId).faceValue) == FOL(loanId).faceValue
- FOL.faceValueExited = SUM(SOL.getCredit)
- fol.faceValue = SUM(Loan.faceValue - Loan.faceValueExited) for all SOLs, FOL
- loan.faceValue == 0 && isFOL(loan) <==> loan.repaid (incorrect)
- upon repayment, the money is locked from the lender until due date, and the protocol earns yield meanwhile
- cash.free + cash.locked ?= deposits
- creating a FOL/SOL decreases a loanOffer maxAmount
- repay should never DoS due to underflow
- only FOLs can be claimed(??)
- a loan is liquidatable if a user is liquidatable (CR < LCR)
- no loan can have a faceValue below the minimumFaceValue
- Taking loan with only virtual collateral does not decrease the borrower CR
- Taking loan with real collateral decreases the borrower CR
- the borrower debt is reduced in: repayment, standard liquidation, liquidation with replacement, self liquidation, borrower exit
- you can exit a SOL (??)
- if isLiquidatable && liquidator has enough cash, the liquidation should always succeed (requires adding more checks to isLiquidatable)
- When a user self liquidates a SOL, it will improve the collateralization ratio of other SOLs. This is because self liquidating decreases the FOL's face value, so it decreases all SOL's debt
- A self liquidation of a FOL will never leave it as a dust loan
- No loan (FOL/SOL) can ever become a dust loan
- the protocol vault is always solvent (how to check for that?)
- $Credit(i) = FV(i) - \sum\limits_{j~where~Originator(j)=i}{FV(j)}$ /// For example, when a loan i exits to another j, Originator(j) = i. This isn't tracked anywhere on-chain, as it's not necessary under the correct accounting conditions, as the loan structure only tracks the folId, not the "originator". But the originator can also be a SOL, when a SOL exits to another SOL. But it can be emitted, which may be used for off-chain metrics, so I guess I'll add that to the event. Also, when doing fuzzing/formal verification, we can also add "ghost variables" to track the "originator", so no need to add it to the protocol, but this concept can be useful in assessing the correct behavior of the exit logic

References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>

## TODOs

- invariant tests
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
- gas optimizations
- separate Loan struct
- use solady for tokens or other simple primitives

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
