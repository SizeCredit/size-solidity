# size-solidity [![Coverage Status](https://coveralls.io/repos/github/SizeCredit/size-solidity/badge.svg?branch=main)](https://coveralls.io/github/SizeCredit/size-solidity?branch=main)

<a href="https://github.com/SizeLending/size-solidity/raw/main/size.png"><img src="https://github.com/SizeLending/size-solidity/raw/main/size.png" width="300" alt="Size"/></a>

Size is a credit marketplace with unified liquidity across maturities.

Networks:

- [Ethereum mainnet](./deployments/mainnet-size-factory.json)
- [Base](./deployments/base-production-size-factory.json)

## Audits

| Date | Version | Auditor | Report |
|------|---------|----------|---------|
| 2025-06-23 | v1.8 | TBD | TBD |
| 2025-06-06 | v1.8-rc.1 | Cantina | TBD |
| 2025-05-26 | v1.8-rc.1 | Custodia Security | TBD |
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

#### Copy trading

In Size v1.6.1, a `copyLimitOrders` function was introduced so that users could copy other users' limit orders. The feature behaved as follows:

- Users could copy borrow/loan offers from other users
- Users could copy both or a single offer from a single address
- Users could specify safeguards per copied curve:
  - min/max APR (safety envelope): if the calculated APR fell outside of this range, the min/max would be used instead
  - min/max tenor: if the requested tenor went outside of this range, the market order would revert
- Users could specify offset APRs to be applied to the curves
- Once a copy offer was set, the user's own offers would be ignored, even if they updated them. Copy offers had precedence until erased (setting them to null/default values)

As an additional safety measure against inverted curves, market orders checked that the borrow offer was lower than the user's loan offer for a given tenor. This did not prevent the copy address from changing curves in a single multicall transaction and bypassing this check.

Notes:

1. Copying another account's limit orders introduced the risk of them placing suboptimal rates and executing market orders against delegators, incurring monetary losses. Only trusted addresses should be copied.
2. The max/min parameters from the `copyLimitOrder` method were not a global max/min for the user-defined limit orders; they were specific to copy offers. Once the copy address offer was no longer valid, max/min guards for mismatched curves would not be applied. The only reason to stop market orders was in the event of "self arbitrage," i.e., for a given tenor, when the borrow curve >= lending curve, since these users could be drained by an attacker by borrowing high and lending low in a single transaction.
3. The offset APR parameters were not validated and could cause market orders to revert depending on the final APR result.

After v1.8, the `CollectionsManager` core contract was introduced, which superseded the copy trading feature, making some of the previous behavior changed. See the corresponding section further down below for more information.

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

#### Custom vaults

Since v1.8, users can select variable pools in addition to Aave to deposit underlying borrow tokens to earn variable yield while their limit orders on the orderbook remain unmatched. This can be done through the `setUserConfiguration` call, which introduces a new `vault` parameter (a breaking change from the previous version). This parameter is used to `setVault` on the `NonTransferrableRebasingTokenVault` contract (e.g., svUSDC), an upgrade from the previous `NonTransferrableScaledTokenV1_5` (e.g., saUSDC) introduced in v1.5. If not set, the default vault is Aave.

The token vault contract is a "vault of vaults" in a sense, a non-transferrable rebasing ERC-20 token that takes underlying tokens from users and deposits them into different vaults. Vaults are whitelisted by the admin, who must confirm these are non-malicious and ERC4626 compatible. In the event where a vault is compromised, only users adopting that vault should be affected (market order reverts, balances unreliable, etc.), and the rest of the protocol should function without issues.

To keep accounting in check, several mappings are : from user to vault, from user to vault shares, and from vault to adapter. Currently, only two adapters are supported through a ["strategy" design pattern](https://refactoring.guru/design-patterns/strategy): `AaveAdapter` and `ERC4626Adapter`. Adapters must implement the `IAdapter` interface (deposit, withdraw, balanceOf, etc.). In the future, other adapters may be introduced by the admin.

In some cases, [withdrawing from the vault may leave "dust" shares](https://slowmist.medium.com/slowmist-aave-v2-security-audit-checklist-0d9ef442436b#5aed) with the user, which are then burned so that they do not roll over during a vault change. These dust shares are tracked in a specific-purpose mapping, and can be used by the admin if needed.

Since there can be an unlimited number of whitelisted vaults, the amount of underlying held by `NonTransferrableRebasingTokenVault` cannot be computed in constant time, so  `totalSupply` loops ver all vaults to calculate the underlying sum. Because of that, it SHOULD NOT be used onchain. In addition, due to the rounding of scaled/shares accounting, the invariant `SUM(balanceOf) == totalSupply()` may not hold true. However, we should still have `SUM(balanceOf) <= totalSupply()`, since `balanceOf` rounds down, and also to guarantee the solvency of the protocol.

#### Collections, curators and rate providers

Since Size v1.8, collections of markets, curators and rate providers are core entities of the ecosystem. This superseedes the previous `copyLimitOrders` feature from v1.6.1, but with more functionality:

- A *collection* is a set of markets grouped under a curator.
- A *Curator* defines *rate providers* (RPs) for each market, which sets yield curves and competes in pricing credit.
- Collections are defined on-chain. Updates made by curators are automatically reflected across all subscribed users without backend or user intervention, since users' yield curves are just pointers.
- When a curator updates the RP for a market, all users subscribed to that collection inherit the new configuration.
- Delegation logic remains under the control of curators, not rate providers, ensuring curators can update or reassign markets freely. In a sense, a curator "owns" the liquidity of users subscribing to their collections. If a RP is not performing well, they can be replaced without compromise to the curator.
- Each market may support multiple rate providers. When overlapping offers exist, market order "takers" can pick the best available rate to them (e.g., lowest loan offer APR during a sell credit market order).
- Curators can define copy limit order configurations, which includes safeguard parameters for each market (min/max APR, min/max tenor), in addition to an offset APR, which is applied at end of the yield curve linear interpolation.
- These copy limit order configurations apply when the user has not defined their own.
- Users can also define their own yield curves and safeguards at the market level. If set, these take precedence over curator defaults.
- If users want to rely exclusively on curator-defined curves, they must explicitly unset their own limit orders (changed behavior from v1.6).
- Users now support multiple yield curves per market, one per collection they are subscribed to, plus an optional personal configuration.
- Curators can transfer ownership of their collections.
- Since users cn subscribe to many collections, each having many rate providers, the "borrow offer should be lower than loan offer" check now has O(C * R) complexity. Users should be aware not to subscribe to too many collections or collections with too many rate providers, or market orders targeting them might revert due to gas costs.
- A rate provider in any market belonging to any collection can prevent all subscribed users from market orders if they set the borrow offer APR greater than or equal to the lend offer APR.

##### Breaking changes

- Copy trading behavior was updated: rate providers' limit orders no longer take precedence over a user's own yield curve.
- During reinitialization:
  - All users who previously used the `copyLimitOrder` feature are now subscribed to a new collection that mirrors the rate provider they had copied.
  - Their existing limit orders are cleared, since these may now be used by the taker side of a market order.
  - By default, market orders now select the user-defined yield curve. Since migrated users will have no personal curve set, market orders will revert unless integrators pass an explicit collection parameter.
- To indicate "no copy," users should pass a `CopyLimitOrderConfig` with all fields set to null except `offsetAPR`. Passing zero min/max bounds will cause reverts—even if the curator has configured valid bounds.
- For the sake of clarity, `getLoanOfferAPR` and `getBorrowOfferAPR` on the `SizeView` contract were renamed to `getUserDefinedLoanOfferAPR` and `getUserDefinedBorrowOfferAPR` to be explicit about whether the yield curve is from a rate provider or from the user themselves.
- Some infrequently utilized `SizeView` functions were removed to make room for the additional `WithCollection` functions and not break the max contract size limit.

## Test

```bash
forge install
forge test
```

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
