# size-v2-solidity

Size V2 Solidity

## Setup

Install <https://github.com/0xClandestine/solplot>

## Invariants

| Property | Category    | Description                                                                              |
| -------- | ----------- | ---------------------------------------------------------------------------------------- |
| C-01     | Collateral  | Locked cash in the user account can't be withdrawn                                       |
| C-02     | Collateral  | The sum of all free cash and locked cash is equal to the token balance of the orderbook                                       |
| R-01     | RANC        | Taking a loan decreases the RANC function  t_DD                                          |
| L-01     | Liquidation | A borrower is eligible to liquidation if it is underwater or if the due date has reached |
| L-02     | Liquidation | A loan is eligible to liquidation if RANC(t_DD) < 0                                      |

References

- <https://hackmd.io/lWCjLs9NSiORaEzaWRJdsQ?view>
