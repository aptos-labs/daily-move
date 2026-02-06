# Liquid NFTs

## Overview

Provides three implementations of NFT liquidity pools, allowing users to trade NFTs for fungible tokens and vice versa. Each implementation uses a different token standard (Coin, Legacy Token V1, Fungible Asset) to demonstrate the evolution of Aptos token standards.

## Difficulty

Advanced

## Concepts Demonstrated

- **NFT liquidity**: Converting NFTs to fungible tokens and back
- **Random selection**: Pseudorandom NFT selection when claiming from the pool
- **Three token standards compared**:
  - `liquid_coin.move` -- Uses Coin + Token Objects (V2)
  - `liquid_coin_legacy.move` -- Uses Coin + Legacy Tokens (V1)
  - `liquid_fungible_asset.move` -- Uses Fungible Assets + Token Objects (V2)
- **SmartVector**: Efficient pool storage for locked NFTs
- **Friend modules**: Shared `common.move` utilities via `public(friend)`
- **Sticky objects**: Non-deletable objects required for fungible asset metadata

## Module Structure

| Module | File | Token Standard | Fungible Standard |
|--------|------|---------------|-------------------|
| `common` | `common.move` | -- | -- | Shared utilities (object creation, pseudorandom, coin/FA creation) |
| `liquid_coin` | `liquid_coin.move` | Token Objects (V2) | Coin |
| `liquid_coin_legacy` | `liquid_coin_legacy.move` | Legacy Tokens (V1) | Coin |
| `liquid_fungible_asset` | `liquid_fungible_asset.move` | Token Objects (V2) | Fungible Asset |

## How It Works

1. **Creator** creates a liquid token for a fixed-supply collection
2. Total fungible supply = collection size * 10^decimals
3. **User deposits NFT** (`liquify`): NFT goes to pool, user gets fungible tokens
4. **User claims NFT** (`claim`): User pays fungible tokens, gets a **random** NFT from pool

## Key Functions (per implementation)

| Function | Description |
|----------|-------------|
| `create_liquid_token` | Creates the liquidity pool for a collection |
| `liquify` | Deposits NFTs into the pool, receives fungible tokens |
| `claim` | Pays fungible tokens, receives random NFTs from pool |

## Pseudorandom Selection

```move
// Uses AUID (globally unique) + timestamp to generate unpredictable index
let auid = transaction_context::generate_auid_address();
let bytes = bcs::to_bytes(&auid);
bytes.append(bcs::to_bytes(&timestamp::now_microseconds()));
let hash = hash::sha3_256(bytes);
let val = from_bcs::to_u256(hash) % (pool_size as u256);
```

> Note: For production use, consider the Aptos on-chain randomness API instead.

## Running Tests

```bash
aptos move test --dev --package-dir snippets/liquid-nfts
```

## Deploy

```bash
aptos move publish --named-addresses fraction_addr=default --package-dir snippets/liquid-nfts
```

## Related Examples

- [Fractional Token](../fractional-token/) -- Single-NFT fractionalization (vs pool-based)
- [Lootbox / Mystery Box](../lootbox/) -- Another randomness-based distribution pattern
- [Composable NFTs](../composable-nfts/) -- Dynamic NFT composition
