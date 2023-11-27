# size-v2-solidity

Size V2 Solidity

## Setup

Install <https://github.com/0xClandestine/solplot>

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
- loan.amountFVExited <= self.FV
- loan.FV == 0 && isFOL(loan) <==> loan.repaid
- loan.repaid ==> !isFOL(loan)
- upon repayment, the money is locked from the lender until due date, and the protocol earns yield meanwhile
- cash.free + cash.locked ?= deposits
- creating a FOL/SOL decreases a loanOffer maxAmount
- repay should never DoS due to underflow
- only FOLs can be claimed(??)


References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>


## TODOs

- chainlink integration
- safe casting int256 to uint256
- check rounding direction
- create helper contracts for liquidation in 1 step (deposit -> liquidate -> withdraw)
- multi-erc20 tokens with different CR per tokens
- natspec
- split contracts (config contract, view/lens contract, etc)
- dust amount for loans
- remove `address(this)` as a reference to the protocol P&N and replace by specific PnL struct