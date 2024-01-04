# size-v2-solidity

Size V2 Solidity

## Coverage

<!-- BEGIN_COVERAGE -->
| File                                                   | % Lines          | % Statements      | % Branches       | % Funcs          |
|--------------------------------------------------------|------------------|-------------------|------------------|------------------|
| src/Size.sol                                           | 94.74% (36/38)   | 94.74% (36/38)    | 100.00% (0/0)    | 93.75% (15/16)   |
| src/SizeView.sol                                       | 100.00% (25/25)  | 100.00% (35/35)   | 100.00% (0/0)    | 100.00% (23/23)  |
| src/libraries/LoanLibrary.sol                          | 42.86% (3/7)     | 35.71% (5/14)     | 100.00% (0/0)    | 60.00% (3/5)     |
| src/libraries/MathLibrary.sol                          | 100.00% (1/1)    | 100.00% (3/3)     | 100.00% (0/0)    | 100.00% (1/1)    |
| src/libraries/OfferLibrary.sol                         | 95.83% (23/24)   | 97.78% (44/45)    | 75.00% (6/8)     | 100.00% (5/5)    |
| src/libraries/actions/BorrowAsLimitOrder.sol           | 100.00% (8/8)    | 100.00% (10/10)   | 100.00% (6/6)    | 100.00% (2/2)    |
| src/libraries/actions/BorrowAsMarketOrder.sol          | 100.00% (55/55)  | 100.00% (71/71)   | 90.91% (20/22)   | 100.00% (4/4)    |
| src/libraries/actions/BorrowerExit.sol                 | 96.30% (26/27)   | 97.06% (33/34)    | 80.00% (8/10)    | 100.00% (2/2)    |
| src/libraries/actions/Claim.sol                        | 100.00% (7/7)    | 100.00% (8/8)     | 100.00% (2/2)    | 100.00% (2/2)    |
| src/libraries/actions/Common.sol                       | 100.00% (44/44)  | 100.00% (65/65)   | 100.00% (16/16)  | 92.31% (12/13)   |
| src/libraries/actions/Deposit.sol                      | 100.00% (10/10)  | 100.00% (17/17)   | 100.00% (4/4)    | 100.00% (2/2)    |
| src/libraries/actions/Initialize.sol                   | 100.00% (25/25)  | 100.00% (33/33)   | 100.00% (16/16)  | 100.00% (2/2)    |
| src/libraries/actions/LendAsLimitOrder.sol             | 100.00% (14/14)  | 100.00% (17/17)   | 91.67% (11/12)   | 100.00% (2/2)    |
| src/libraries/actions/LendAsMarketOrder.sol            | 95.65% (22/23)   | 96.43% (27/28)    | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/actions/LiquidateLoan.sol                | 100.00% (28/28)  | 100.00% (38/38)   | 75.00% (6/8)     | 100.00% (2/2)    |
| src/libraries/actions/LiquidateLoanWithReplacement.sol | 100.00% (23/23)  | 100.00% (26/26)   | 75.00% (3/4)     | 100.00% (2/2)    |
| src/libraries/actions/MoveToVariablePool.sol           | 100.00% (13/13)  | 100.00% (16/16)   | 83.33% (5/6)     | 100.00% (2/2)    |
| src/libraries/actions/Repay.sol                        | 100.00% (14/14)  | 100.00% (14/14)   | 87.50% (7/8)     | 100.00% (2/2)    |
| src/libraries/actions/SelfLiquidateLoan.sol            | 100.00% (23/23)  | 100.00% (28/28)   | 80.00% (8/10)    | 100.00% (2/2)    |
| src/libraries/actions/UpdateConfig.sol                 | 100.00% (22/22)  | 100.00% (24/24)   | 100.00% (16/16)  | 100.00% (2/2)    |
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

- creating a FOL/SOL decreases a offer maxAmount
- you can exit a SOL
- Taking loan with only virtual collateral does not decrease the borrower CR
- Taking loan with real collateral decreases the borrower CR

- Repay should never DoS due to underflow
- If isLiquidatable && liquidator has enough cash, the liquidation should always succeed (requires adding more checks to isLiquidatable)
- When a user self liquidates a SOL, it will improve the collateralization ratio of other SOLs. This is because self liquidating decreases the FOL's face value, so it decreases all SOL's debt
- A self liquidation of a FOL will never leave it as a dust loan
- No loan (FOL/SOL) can ever become a dust loan
- the protocol vault is always solvent (how to check for that?)
- $Credit(i) = FV(i) - \sum\limits_{j~where~Exiter(j)=i}{FV(j)}$ /// For example, when a loan i exits to another j, Exiter(j) = i. This isn't tracked anywhere on-chain, as it's not necessary under the correct accounting conditions, as the loan structure only tracks the folId, not the "originator". But the originator can also be a SOL, when a SOL exits to another SOL. But it can be emitted, which may be used for off-chain metrics, so I guess I'll add that to the event. Also, when doing fuzzing/formal verification, we can also add "ghost variables" to track the "originator", so no need to add it to the protocol, but this concept can be useful in assessing the correct behavior of the exit logic
- The VP utilization ratio should never be greater than 1

References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>

## TODOs

- TODO: add updateConfig tests
- TODO: multicall
- TODO: liquidation has a parameter for CR in case they/bot wants
- TODO: origination fee & loan fee
- TODO: loan fee
- TODO: VP updates

- invariant tests
- add more unit tests where block.timestamp is e.g. "December 29, 2023", so that it is more realistic
- add tests with other types of yield curves (not only flat)
- also add buckets of different sizes, not only spaced by 1 (second), but also 30 days, 1 week, etc etc
- add test for dueDate NOW
- borrowing from yourself you increase your debt without getting any cash, and can put you closer to liquidation
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
