# size-solidity

<a href="https://github.com/SizeLending/size-solidity/raw/main/size.png"><img src="https://github.com/SizeLending/size-solidity/raw/main/size.png" width="300" alt="Size"/></a>

Size is a credit marketplace with unified liquidity across maturities.

Networks:

- [Ethereum mainnet](./deployments/mainnet-size-factory.json)
- [Base](./deployments/base-production-size-factory.json)

## Audits

| Date | Version | Auditor | Report |
|------|---------|----------|---------|
| 2025-02-26 | v1.7 | Cantina | [Report](./audits/2025-02-26-Cantina.pdf) |
| 2025-02-12 | v1.6.1 | Custodia Security | [Report](./audits/2025-02-12-Custodia-Security.pdf) |
| 2024-12-10 | v1.5.1 | ChainDefenders | [Report](./audits/2024-12-10-ChainDefenders.pdf) |
| 2024-11-13 | v1.5 | Custodia Security | [Report](./audits/2024-11-13-Custodia-Security.pdf) |
| 2024-06-10 | v1.0 | Code4rena | [Report](./audits/2024-06-10-Code4rena.pdf) |
| 2024-06-08 | v1.0-rc | Spearbit | [Report](./audits/2024-06-08-Spearbit.pdf) |
| 2024-03-26 | v1.0-beta | Solidified | [Report](./audits/2024-03-26-Solidified.pdf) |

For bug reports, please refer to our [Bug Bounty Program](https://cantina.xyz/bounties/c5811be1-cc87-4418-80b0-f0b50f7e5849)

## Documentation

### Overview, Accounting and Protocol Design

- [Whitepaper](https://docs.size.cash/)

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

The `Multicall` pattern is also available to allow users to perform a sequence of multiple actions, such as depositing borrow tokens, liquidating an underwater borrower, and withdrawing all liquidated collateral. **Note:** in order to accept ether deposits through multicalls, all user-facing functions have the [`payable`](https://github.com/sherlock-audit/2023-06-tokemak-judging/issues/215) modifier, and `deposit` always uses `address(this).balance` to wrap ether. This means leftover amounts, if [sent forcibly](https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/force-feeding/), are always credited to the depositor.

Additional safety features were employed, such as different levels of Access Control (ADMIN, PAUSER_ROLE, KEEPER_ROLE, BORROW_RATE_UPDATER_ROLE), and Pause.

#### Tokens

In order to address donation and reentrancy attacks, the following measures were adopted:

- No withdraws of native ether, only wrapped ether (WETH)
- Underlying borrow and collateral tokens, such as USDC and WETH, are converted 1:1 into deposit tokens via `deposit`, which mints `szaUSDC` and `szWETH`, and received back via `withdraw`, which burns deposit tokens 1:1 in exchange for the underlying tokens.

#### Maths

All mathematical operations are implemented with explicit rounding (`mulDivUp` or `mulDivDown`) using Solady's [FixedPointMathLib](https://github.com/Vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol). Whenever a taker-maker operation occurs, all rounding tries to favor the maker, who is the passive party. In some generic situations, such as in yield curve calculations, the rounding is always in one direction.

Decimal amounts are preserved until a conversion is necessary:

- USDC/aUSDC: 6 decimals
- WETH/szETH: 18 decimals
- szDebt: same as borrow token
- Price feeds: 18 decimals

All percentages are expressed in 18 decimals. For example, a 150% liquidation collateral ratio is represented as 1500000000000000000.

#### Oracles

##### Price Feed

A contract that provides the price of ETH in terms of USDC in 18 decimals. For example, a price of 3327.39 ETH/USDC is represented as 3327390000000000000000.

##### Variable Pool Borrow Rate Feed

In order to set the current market average value of USDC variable borrow rates, we perform an off-chain calculation on Aave's rate, convert it to 18 decimals, and store it in the Size contract. For example, a rate of 2.49% on Aave v3 is represented as 24900000000000000. The admin can disable this feature by setting the stale interval to zero. If the oracle information is stale, orders relying on the variable rate feed cannot be matched.

#### Factory

After v1.5, markets can be deployed through a `SizeFactory` contract. This contract is a central point of the Size ecosystem, as it enables `NonTransferrableScaledTokenV1_5` contracts (such as `saUSDC`) to mint/burn deposit tokens to users who deposit/withdraw, essentially enabling shared liquidity across different markets. For example, a user may deposit USDC to the WETH/USDC market but use the same liquidity to lend on the cbBTC/USDC market.

After v1.7, the `SizeFactory` also holds the access control for all Size markets. A fallback mechanism is still used on individual markets, where roles are first checked on each deployment, and then on the factory contract. This means the administrator must take appropriate care to revoke roles both on the factory and on individual markets in case of a privilege de-escalation scenario. The benefit of this approach is that existing markets will continue to work as usual even if all accounts have not been granted roles on the SizeFactory contract. Note: This change allows the factory access control to act on behalf of a role (e.g., pause a market) but does not grant it the ability to manage roles (grant/revoke). Role management in `AccessControl`'s for market is strictly governed by the market-scoped `DEFAULT_ADMIN_ROLE`, which is not overridden by the factory access control, which means, if the admin revokes his role with `renounceRole`, it may not be able to revoke other roles later.

#### Authorization

Users can authorize other operator accounts to perform specific actions or any action on their behalf on any market (per chain) through a new `setAuthorization` method called on the `SizeFactory` introduced in v1.7. This enables users to delegate all Size functionalities to third parties, enabling more complex strategies and automations.

Some use cases of delegation are:

- One-click leverage through a looping contract
- Auto-refinancing of loans
- Stop-loss for price drops in collateral through automated self-liquidations
- Automated submission of limit orders into newly deployed markets

This powerful capability comes with associated risks, and, as such, users must take extra care regarding whom and what they authorize, and should only authorize operators they fully trust, such as audited smart contracts or wallets they control.

A non-exhaustive list of the risks of improper authorization includes:

- Authorizing `deposit` enables the operator to deposit user funds to their account
- Authorizing `withdraw` enables the operator to withdraw user funds to their account
- Authorizing `sellCreditLimit` enables the operator to set sub-optimal borrow offers
- Authorizing `buyCreditLimit` enables the operator to set sub-optimal loan offers
- Authorizing both `buyCreditLimit` and `sellCreditLimit` enables the operator to set the borrow offer above the loan offer and create a self-arbitrage opportunity for the user
- Authorizing `sellCreditMarket` enables the operator to borrow on behalf of the user and send the borrowed cash to their account, or to sell positions not for-sale
- Authorizing `buyCreditMarket` enables the operator to lend on behalf of the user and send the credit to their account
- Authorizing `selfLiquidate` enables the operator to self liquidate on their behalf when the debt position is likely to become liquidatable in the short term
- Authorizing `compensate` enables the operator to compensate loans on their behalf from risky debt positions
- Authorizing `setUserConfiguration` enables the operator to change opening CR and other important account configurations
- Authorizing `copyLimitOrders` enables the operator to copy from addresses with parameters that would make market orders against them revert

Because of the related risks, a recommended pattern is to authorize pre-vetted smart contracts in the beginning of a `multicall` operation, and revoke the authorization at the end of it. This way, the strategy contract will not hold any funds or credit on behalf of the user, and will be only responsible for specific actions during a limited time.

#### Copy trading

Since Size v1.6.1, users can copy other users' limit orders.

- Users can copy borrow/loan offers from other users
- Users can copy both or a single offer from a single address
- Users can specify safeguards per copied curve:
  - min/max APR (safety envelope): if the calculated APR falls outside of this range, the min/max is used instead
  - min/max tenor: if the requested tenor goes outside of this range, the market order reverts
- Users can specify offset APRs to be applied to the curves
- Once a copy offer is set, the user's own offers should be ignored, even if they update them. Copy offers have precedence until erased (setting them to null/default vales)

As an additional safety measure against inverted curves, market orders check that the borrow offer is lower than the user's loan offer for a given tenor. This does not prevent the copy address from changing curves in a single multicall transaction and bypassing this check.

Notes

1. Copying another account's limit orders introduces the risk of them placing suboptimal rates and executing market orders against delegators, incurring monetary losses. Only trusted addresses should be copied.
2. The max/min params from the `copyLimitOrder` method are not global max/min for the user-defined limit orders; they are specific to copy offers. Once the copy address offer is no longer valid, max/min guards for mismatched curves will not be applied. The only reason to stop market orders is in the event of "self arbitrage," i.e., for a given tenor, when the borrow curve >= lending curve, since these users could be drained by an attacker by borrowing high and lending low in a single transaction.
3. The offset APR parameters are not validated and can cause market orders reverts depending on the final APR result

## Test

```bash
forge install
forge test
```

## Coverage

```bash
yarn coverage
```

<!-- BEGIN_COVERAGE -->
### FIles

```markdown
| File                                                                    | % Lines            | % Statements       | % Branches       | % Funcs          |
+=========================================================================================================================================================+
| src/factory/SizeFactory.sol                                             | 100.00% (60/60)    | 100.00% (50/50)    | 100.00% (6/6)    | 100.00% (13/13)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/factory/SizeFactoryOffchainGetters.sol                              | 100.00% (23/23)    | 100.00% (27/27)    | 100.00% (2/2)    | 100.00% (6/6)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/factory/libraries/Authorization.sol                                 | 100.00% (18/18)    | 100.00% (21/21)    | 100.00% (0/0)    | 100.00% (7/7)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/factory/libraries/MarketFactoryLibrary.sol                          | 100.00% (3/3)      | 100.00% (3/3)      | 100.00% (0/0)    | 100.00% (1/1)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/factory/libraries/NonTransferrableScaledTokenV1_5FactoryLibrary.sol | 100.00% (2/2)      | 100.00% (1/1)      | 100.00% (0/0)    | 100.00% (1/1)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/factory/libraries/PriceFeedFactoryLibrary.sol                       | 100.00% (2/2)      | 100.00% (1/1)      | 100.00% (0/0)    | 100.00% (1/1)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/Size.sol                                                     | 100.00% (125/125)  | 100.00% (93/93)    | 100.00% (11/11)  | 100.00% (37/37)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/SizeView.sol                                                 | 100.00% (49/49)    | 100.00% (44/44)    | 100.00% (1/1)    | 100.00% (23/23)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/AccountingLibrary.sol                              | 96.81% (91/94)     | 96.88% (93/96)     | 86.96% (20/23)   | 100.00% (12/12)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/CapsLibrary.sol                                    | 93.33% (14/15)     | 93.33% (14/15)     | 75.00% (3/4)     | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/DepositTokenLibrary.sol                            | 100.00% (14/14)    | 100.00% (10/10)    | 100.00% (0/0)    | 100.00% (4/4)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/LoanLibrary.sol                                    | 97.44% (38/39)     | 97.83% (45/46)     | 93.33% (14/15)   | 100.00% (8/8)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/Math.sol                                           | 100.00% (23/23)    | 100.00% (25/25)    | 100.00% (5/5)    | 100.00% (6/6)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/Multicall.sol                                      | 100.00% (11/11)    | 100.00% (16/16)    | 100.00% (0/0)    | 100.00% (1/1)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/OfferLibrary.sol                                   | 100.00% (52/52)    | 100.00% (67/67)    | 100.00% (14/14)  | 100.00% (10/10)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/RiskLibrary.sol                                    | 97.06% (33/34)     | 97.83% (45/46)     | 83.33% (5/6)     | 100.00% (9/9)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/YieldCurveLibrary.sol                              | 97.44% (38/39)     | 98.25% (56/57)     | 93.33% (14/15)   | 100.00% (4/4)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/BuyCreditLimit.sol                         | 100.00% (13/13)    | 100.00% (11/11)    | 100.00% (2/2)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/BuyCreditMarket.sol                        | 100.00% (66/66)    | 100.00% (73/73)    | 100.00% (19/19)  | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Claim.sol                                  | 100.00% (13/13)    | 100.00% (16/16)    | 100.00% (2/2)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Compensate.sol                             | 100.00% (45/45)    | 100.00% (46/46)    | 100.00% (9/9)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/CopyLimitOrders.sol                        | 100.00% (30/30)    | 100.00% (27/27)    | 100.00% (12/12)  | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Deposit.sol                                | 100.00% (32/32)    | 100.00% (30/30)    | 100.00% (9/9)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Initialize.sol                             | 100.00% (86/86)    | 100.00% (77/77)    | 100.00% (20/20)  | 100.00% (11/11)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Liquidate.sol                              | 100.00% (32/32)    | 100.00% (38/38)    | 100.00% (5/5)    | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/LiquidateWithReplacement.sol               | 100.00% (35/35)    | 100.00% (41/41)    | 100.00% (6/6)    | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/PartialRepay.sol                           | 100.00% (19/19)    | 100.00% (21/21)    | 100.00% (4/4)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Repay.sol                                  | 100.00% (11/11)    | 100.00% (11/11)    | 100.00% (2/2)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/SelfLiquidate.sol                          | 100.00% (24/24)    | 100.00% (27/27)    | 100.00% (4/4)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/SellCreditLimit.sol                        | 100.00% (13/13)    | 100.00% (11/11)    | 100.00% (2/2)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/SellCreditMarket.sol                       | 100.00% (60/60)    | 100.00% (64/64)    | 100.00% (18/18)  | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/SetUserConfiguration.sol                   | 100.00% (22/22)    | 100.00% (27/27)    | 100.00% (3/3)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/UpdateConfig.sol                           | 100.00% (53/53)    | 100.00% (51/51)    | 100.00% (32/32)  | 100.00% (5/5)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/libraries/actions/Withdraw.sol                               | 100.00% (26/26)    | 100.00% (24/24)    | 100.00% (8/8)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/token/NonTransferrableScaledTokenV1_5.sol                    | 100.00% (90/90)    | 100.00% (87/87)    | 100.00% (8/8)    | 100.00% (20/20)  |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/market/token/NonTransferrableToken.sol                              | 100.00% (19/19)    | 100.00% (13/13)    | 100.00% (1/1)    | 100.00% (8/8)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/adapters/ChainlinkPriceFeed.sol                              | 100.00% (25/25)    | 100.00% (39/39)    | 100.00% (9/9)    | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/adapters/ChainlinkSequencerUptimeFeed.sol                    | 100.00% (9/9)      | 100.00% (11/11)    | 100.00% (3/3)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/adapters/UniswapV3PriceFeed.sol                              | 100.00% (29/29)    | 100.00% (40/40)    | 100.00% (5/5)    | 100.00% (2/2)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/adapters/morpho/MorphoPriceFeed.sol                          | 0.00% (0/15)       | 0.00% (0/23)       | 0.00% (0/3)      | 0.00% (0/2)      |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.1/PriceFeed.sol                                         | 100.00% (18/18)    | 100.00% (16/16)    | 100.00% (2/2)    | 100.00% (6/6)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.2/PriceFeedChainlinkUniswapV3TWAPx2.sol                 | 0.00% (0/13)       | 0.00% (0/13)       | 0.00% (0/2)      | 0.00% (0/3)      |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.2/PriceFeedUniswapV3TWAPChainlink.sol                   | 100.00% (11/11)    | 100.00% (12/12)    | 100.00% (0/0)    | 100.00% (3/3)    |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.3/PriceFeedUniswapV3TWAP.sol                            | 0.00% (0/8)        | 0.00% (0/7)        | 100.00% (0/0)    | 0.00% (0/3)      |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.6.2/PriceFeedMorpho.sol                                   | 0.00% (0/8)        | 0.00% (0/7)        | 100.00% (0/0)    | 0.00% (0/3)      |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.7.1/PriceFeedMorphoChainlinkOracleV2.sol                  | 0.00% (0/9)        | 0.00% (0/8)        | 0.00% (0/1)      | 0.00% (0/3)      |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.7.1/PriceFeedPendleChainlink.sol                          | 0.00% (0/18)       | 0.00% (0/23)       | 0.00% (0/1)      | 0.00% (0/3)      |
|-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| Total                                                                   | 94.64% (1377/1455) | 94.18% (1424/1512) | 95.24% (280/294) | 93.39% (240/257) |
╰-------------------------------------------------------------------------+--------------------+--------------------+------------------+------------------╯
```

### Tests per file

```markdown
┌──────────────────────────────────────┬────────┐
│ (index)                              │ Values │
├──────────────────────────────────────┼────────┤
│ AuthorizationBuyCreditLimit          │ 2      │
│ AuthorizationBuyCreditMarket         │ 2      │
│ AuthorizationCompensate              │ 2      │
│ AuthorizationCopyLimitOrders         │ 2      │
│ AuthorizationDeposit                 │ 4      │
│ AuthorizationRevokeAllAuthorizations │ 1      │
│ AuthorizationSelfLiquidate           │ 2      │
│ AuthorizationSellCreditLimit         │ 2      │
│ AuthorizationSellCreditMarket        │ 2      │
│ AuthorizationSetAuthorization        │ 9      │
│ AuthorizationSetUserConfiguration    │ 2      │
│ AuthorizationWithdraw                │ 2      │
│ BuyCreditLimit                       │ 4      │
│ BuyCreditMarket                      │ 10     │
│ ChainlinkPriceFeed                   │ 8      │
│ ChainlinkSequencerUptimeFeed         │ 2      │
│ Claim                                │ 10     │
│ Compensate                           │ 21     │
│ CopyLimitOrders                      │ 16     │
│ CryticToFoundry                      │ 31     │
│ Deposit                              │ 5      │
│ GenericMarket                        │ 20     │
│ Initialize                           │ 4      │
│ LiquidateWithReplacement             │ 6      │
│ Liquidate                            │ 12     │
│ Math                                 │ 6      │
│ Multicall                            │ 10     │
│ NonTransferrableScaledTokenV1        │ 21     │
│ NonTransferrableToken                │ 8      │
│ OfferLibrary                         │ 1      │
│ PartialRepay                         │ 4      │
│ Pause                                │ 2      │
│ PriceFeedUniswapV3TWAPChainlink      │ 3      │
│ PriceFeed                            │ 9      │
│ ReinitializeV1                       │ 5      │
│ Repay                                │ 7      │
│ SelfLiquidate                        │ 10     │
│ SellCreditLimit                      │ 5      │
│ SellCreditMarket                     │ 13     │
│ SetUserConfiguration                 │ 3      │
│ SizeFactoryReinitializeV1            │ 5      │
│ SizeFactory                          │ 15     │
│ SizeView                             │ 5      │
│ SwapData                             │ 3      │
│ UniswapV3PriceFeed                   │ 5      │
│ UpdateConfig                         │ 7      │
│ Upgrade                              │ 2      │
│ Withdraw                             │ 9      │
│ YieldCurve                           │ 15     │
└──────────────────────────────────────┴────────┘
```
<!-- END_COVERAGE -->

## Protocol invariants

### Invariants implemented

- Check [`PropertiesSpecifications.sol`](./test/invariants/PropertiesSpecifications.sol)

Run Echidna with

```bash
yarn echidna-property
yarn echidna-assertion
```

### Onchain fuzzing

```bash
source .env
FOUNDRY_PROFILE=fork FOUNDRY_INVARIANT_RUNS=0 FOUNDRY_INVARIANT_DEPTH=0 forge test --mc FoundryForkTester -vvvvv --ffi
```

Check the coverage report with

```bash
yarn echidna-coverage
```

## Formal Verification

- [`Math.binarySearch`](./test/libraries/Math.t.sol)

Run Halmos with

```bash
for i in {0..5}; do halmos --loop $i; done
```

## Known limitations

- The protocol does not support rebasing/fee-on-transfer tokens
- The protocol only supports tokens compliant with the IERC20Metadata interface
- The protocol only supports pre-vetted tokens
- The protocol owner, KEEPER_ROLE, PAUSER_ROLE, and BORROW_RATE_UPDATER_ROLE are trusted
- The protocol uses Uniswap TWAP as a fallback oracle in case Chainlink is stale.
- In case Chainlink reports a wrong price, the protocol state cannot be guaranteed. This may cause incorrect liquidations, among other issues
- In case the protocol is paused, the price of the collateral may change during the unpause event. This may cause unforseen liquidations, among other issues
- It is not possible to pause individual functions. Nevertheless, BORROW_RATE_UPDATER_ROLE and admin functions are enabled even if the protocol is paused
- Users blacklisted by underlying tokens (e.g. USDC) may be unable to withdraw
- If the Variable Pool (Aave v3) fails to `supply` or `withdraw` for any reason, such as supply caps, Size's `deposit` and `withdraw` may be prevented
- Centralization risk related to integrations (USDC, Aave v3, Chainlink) are out of scope
- The Variable Pool Borrow Rate feed is trusted and users of rate hook adopt oracle risk of buying/selling credit at unsatisfactory prices
- The insurance fund (out of scope for this project) may not be able to make all lenders whole, maybe unfair, and may be manipulated
- LiquidateWithReplacement might not be available for the big enough debt positions
- The fragmentation fee meant to subsidize `claim` operations by protocol-owned keeper bots during credit splits are not charged during loan origination
- All issues acknowledged on previous audits and automated findings

## Deployment

### Environment Setup

Ensure your `.env` file in the root directory of your project contains the following variables:

```bash
API_KEY_ALCHEMY=<Your Alchemy API Key>
API_KEY_ETHERSCAN=<Your Etherscan API Key>
DEPLOYER_ADDRESS=<Deployer's Ethereum Address>
DEPLOYER_ACCOUNT=<Name of the Deployer's Account in Foundry>
OWNER=<Owner's Address>
FEE_RECIPIENT=<Fee Recipient's Address>
NETWORK_CONFIGURATION=<Network Configuration>
RPC_URL=<Network Name>
```

### Account Management

The `DEPLOYER_ACCOUNT` is a reference to the name of an account managed by Foundry's `cast wallet` feature. To create and import a new deployer wallet using a private key, use the following command:

```bash
cast wallet import DEPLOYER_ACCOUNT_NAME --private-key $(cast wallet new | grep Private | awk -F 'Private key: ' '{print $2}')
```

### Network Configuration

Ensure that the `NETWORK_CONFIGURATION` is set according to the network options you are deploying to. For example, you can create a configuration `base-mocks` and another `base-production` without mocks. Also, ensure that `RPC_URL` is set according to the network you are deploying to. In the previous case, both would be equal to `base` as in your `foundry.toml`. You can see the available network configuration in `script/Networks.sol`.

You can set relevant `NetworkParams` to `address(0)` if you are deploying with mock contracts or require specific network parameters.

```bash
source .env
export NETWORK_CONFIGURATION=base-production-weth-usdc
forge script script/Deploy.s.sol --rpc-url $RPC_URL --gas-limit 30000000 --sender $DEPLOYER_ADDRESS --account $DEPLOYER_ACCOUNT --ffi --verify -vvvvv
```

If it does not work, try removing `--verify`

### Deployment checklist

0. Due dilligence on borrow/collateral tokens: non-rebasing, IERC20Metadata
1. Deploy
2. Grant `KEEPER_ROLE` to liquidation contract
3. Grant `BORROW_RATE_UPDATER_ROLE` to bot
4. Grant `PAUSER_ROLE` to bot, multisig signers

## Upgrade

```bash
source .env.base_sepolia
forge script script/Upgrade.s.sol --rpc-url $RPC_URL --gas-limit 30000000 --sender $DEPLOYER_ADDRESS --account $DEPLOYER_ACCOUNT --ffi --verify -vvvvv [--slow]
```
