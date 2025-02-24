# size-solidity

<a href="https://github.com/SizeLending/size-solidity/raw/main/size.png"><img src="https://github.com/SizeLending/size-solidity/raw/main/size.png" width="300" alt="Size"/></a>

Size is a credit marketplace with unified liquidity across maturities.

Networks:

- [Ethereum mainnet](./deployments/mainnet-size-factory.json)
- [Base](./deployments/base-production-size-factory.json)

## Audits

| Date | Version | Auditor | Report |
|------|---------|----------|---------|
| TBD | v1.7 | TBD | TBD |
| 2025-02-12 | v1.6.1 | Custodia Security | [Report](./audits/2025-02-12-Custodia-Security.pdf) |
| 2024-12-10 | v1.5.1 | ChainDefenders | [Report](./audits/2024-12-10-ChainDefenders.pdf) |
| 2024-11-13 | v1.5 | Custodia Security | [Report](./audits/2024-11-13-Custodia-Security.pdf) |
| 2024-06-10 | v1.0 | Code4rena | [Report](https://code4rena.com/reports/2024-06-size) |
| 2024-06-08 | v1.0-rc | Spearbit | [Report](./audits/2024-06-08-Spearbit.pdf) |
| 2024-03-26 | v1.0-beta | Solidified | [Report](./audits/2024-03-26-Solidified.pdf) |
| 2024-03-19 | v1.0-alpha | LightChaserV3 | [Report](./audits/2024-03-19-LightChaserV3.md) |

For bug reports, please refer to our [Bug Bounty Program](https://app.hats.finance/bug-bounties/size-0xd915dc4630c8957e7aabb44df6309f6f4cfcf9c0/rewards)

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
| File                                                                 | % Lines            | % Statements       | % Branches       | % Funcs          |
+======================================================================================================================================================+
| src/Size.sol                                                         | 100.00% (85/85)    | 100.00% (67/67)    | 100.00% (3/3)    | 100.00% (23/23)  |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/SizeView.sol                                                     | 100.00% (49/49)    | 100.00% (45/45)    | 100.00% (1/1)    | 100.00% (23/23)  |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/AccountingLibrary.sol                                  | 96.81% (91/94)     | 96.88% (93/96)     | 86.96% (20/23)   | 100.00% (12/12)  |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/CapsLibrary.sol                                        | 93.33% (14/15)     | 93.33% (14/15)     | 75.00% (3/4)     | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/DepositTokenLibrary.sol                                | 100.00% (14/14)    | 100.00% (10/10)    | 100.00% (0/0)    | 100.00% (4/4)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/LoanLibrary.sol                                        | 97.44% (38/39)     | 97.83% (45/46)     | 93.33% (14/15)   | 100.00% (8/8)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/Math.sol                                               | 100.00% (23/23)    | 100.00% (25/25)    | 100.00% (5/5)    | 100.00% (6/6)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/Multicall.sol                                          | 100.00% (11/11)    | 100.00% (16/16)    | 100.00% (0/0)    | 100.00% (1/1)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/OfferLibrary.sol                                       | 100.00% (52/52)    | 100.00% (67/67)    | 100.00% (14/14)  | 100.00% (10/10)  |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/RiskLibrary.sol                                        | 97.06% (33/34)     | 97.83% (45/46)     | 83.33% (5/6)     | 100.00% (9/9)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/YieldCurveLibrary.sol                                  | 92.31% (36/39)     | 96.49% (55/57)     | 86.67% (13/15)   | 100.00% (4/4)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/BuyCreditLimit.sol                             | 100.00% (7/7)      | 100.00% (5/5)      | 100.00% (1/1)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/BuyCreditMarket.sol                            | 100.00% (56/56)    | 100.00% (65/65)    | 100.00% (16/16)  | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Claim.sol                                      | 100.00% (13/13)    | 100.00% (16/16)    | 100.00% (2/2)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Compensate.sol                                 | 100.00% (50/50)    | 100.00% (53/53)    | 100.00% (13/13)  | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/CopyLimitOrders.sol                            | 100.00% (24/24)    | 100.00% (21/21)    | 100.00% (11/11)  | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Deposit.sol                                    | 100.00% (25/25)    | 100.00% (24/24)    | 100.00% (8/8)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Initialize.sol                                 | 100.00% (82/82)    | 100.00% (73/73)    | 100.00% (18/18)  | 100.00% (11/11)  |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Liquidate.sol                                  | 100.00% (32/32)    | 100.00% (38/38)    | 100.00% (5/5)    | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/LiquidateWithReplacement.sol                   | 100.00% (35/35)    | 100.00% (43/43)    | 100.00% (5/5)    | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Repay.sol                                      | 100.00% (11/11)    | 100.00% (11/11)    | 100.00% (2/2)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/SelfLiquidate.sol                              | 100.00% (14/14)    | 100.00% (17/17)    | 100.00% (2/2)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/SellCreditLimit.sol                            | 100.00% (7/7)      | 100.00% (5/5)      | 100.00% (1/1)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/SellCreditMarket.sol                           | 100.00% (50/50)    | 100.00% (56/56)    | 100.00% (15/15)  | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/SetUserConfiguration.sol                       | 100.00% (16/16)    | 100.00% (21/21)    | 100.00% (2/2)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/UpdateConfig.sol                               | 100.00% (53/53)    | 100.00% (51/51)    | 100.00% (32/32)  | 100.00% (5/5)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/libraries/actions/Withdraw.sol                                   | 100.00% (20/20)    | 100.00% (18/18)    | 100.00% (7/7)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.1/PriceFeed.sol                                      | 100.00% (18/18)    | 100.00% (20/20)    | 100.00% (0/0)    | 100.00% (6/6)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.1/adapters/ChainlinkPriceFeed.sol                    | 100.00% (25/25)    | 100.00% (39/39)    | 100.00% (9/9)    | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol          | 100.00% (9/9)      | 100.00% (11/11)    | 100.00% (3/3)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.1/adapters/UniswapV3PriceFeed.sol                    | 100.00% (29/29)    | 100.00% (40/40)    | 100.00% (5/5)    | 100.00% (2/2)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.2/PriceFeedChainlinkUniswapV3TWAPx2.sol              | 0.00% (0/13)       | 0.00% (0/17)       | 100.00% (0/0)    | 0.00% (0/3)      |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.2/PriceFeedUniswapV3TWAPChainlink.sol                | 100.00% (11/11)    | 100.00% (12/12)    | 100.00% (0/0)    | 100.00% (3/3)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/oracle/v1.5.3/PriceFeedUniswapV3TWAP.sol                         | 0.00% (0/8)        | 0.00% (0/7)        | 100.00% (0/0)    | 0.00% (0/3)      |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/token/NonTransferrableToken.sol                                  | 100.00% (19/19)    | 100.00% (13/13)    | 100.00% (1/1)    | 100.00% (8/8)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/v1.5/SizeFactory.sol                                             | 97.37% (111/114)   | 98.99% (98/99)     | 90.00% (9/10)    | 96.97% (32/33)   |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/v1.5/libraries/MarketFactoryLibrary.sol                          | 100.00% (3/3)      | 100.00% (3/3)      | 100.00% (0/0)    | 100.00% (1/1)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/v1.5/libraries/NonTransferrableScaledTokenV1_5FactoryLibrary.sol | 100.00% (2/2)      | 100.00% (1/1)      | 100.00% (0/0)    | 100.00% (1/1)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/v1.5/libraries/PriceFeedFactoryLibrary.sol                       | 100.00% (2/2)      | 100.00% (1/1)      | 100.00% (0/0)    | 100.00% (1/1)    |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| src/v1.5/token/NonTransferrableScaledTokenV1_5.sol                   | 87.78% (79/90)     | 90.80% (79/87)     | 25.00% (2/8)     | 85.00% (17/20)   |
|----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------|
| Total                                                                | 96.60% (1249/1293) | 96.98% (1316/1357) | 94.27% (247/262) | 95.78% (227/237) |
╰----------------------------------------------------------------------+--------------------+--------------------+------------------+------------------╯
```

### Tests per file

```markdown
┌─────────────────────────────────┬────────┐
│ (index)                         │ Values │
├─────────────────────────────────┼────────┤
│ BuyCreditLimit                  │ 4      │
│ BuyCreditMarket                 │ 10     │
│ ChainlinkPriceFeed              │ 8      │
│ ChainlinkSequencerUptimeFeed    │ 2      │
│ Claim                           │ 10     │
│ Compensate                      │ 20     │
│ CopyLimitOrders                 │ 16     │
│ CryticToFoundry                 │ 27     │
│ Deposit                         │ 5      │
│ GenericMarket                   │ 20     │
│ Initialize                      │ 4      │
│ LiquidateWithReplacement        │ 6      │
│ Liquidate                       │ 12     │
│ Math                            │ 6      │
│ Multicall                       │ 9      │
│ NonTransferrableScaledTokenV1   │ 17     │
│ NonTransferrableToken           │ 8      │
│ OfferLibrary                    │ 1      │
│ Pause                           │ 2      │
│ PriceFeedUniswapV3TWAPChainlink │ 3      │
│ PriceFeed                       │ 9      │
│ Repay                           │ 7      │
│ SelfLiquidate                   │ 10     │
│ SellCreditLimit                 │ 5      │
│ SellCreditMarket                │ 13     │
│ SetUserConfiguration            │ 3      │
│ SizeFactory                     │ 36     │
│ SizeView                        │ 5      │
│ SwapData                        │ 3      │
│ UniswapV3PriceFeed              │ 5      │
│ UpdateConfig                    │ 7      │
│ Upgrade                         │ 2      │
│ Withdraw                        │ 9      │
│ YieldCurve                      │ 14     │
└─────────────────────────────────┴────────┘
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
