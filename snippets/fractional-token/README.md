# Fractional Token

## Overview

Demonstrates how to fractionalize a digital asset (NFT) into fungible tokens and recombine them later. A single NFT is locked in an object, fungible shares are minted to the owner, and the NFT can only be reclaimed when all shares are held by one account.

## Difficulty

Advanced

## Concepts Demonstrated

- **Fractionalization**: Converting one NFT into N fungible tokens
- **Primary fungible stores**: Using `primary_fungible_store::create_primary_store_enabled_fungible_asset`
- **Named objects**: Deterministic address for the fractionalization container
- **Transfer locking**: Disabling ungated transfer on the locked NFT so it can't be moved
- **Minting and burning**: Creating a fixed supply of fungible tokens, then burning them all on recombination
- **Storage recovery**: Cleaning up objects to reclaim storage gas after recombination

## Key Structs

| Struct | Purpose |
|--------|---------|
| `FractionalDigitalAsset` | Holds the locked NFT, `ExtendRef`, `BurnRef`, and `TransferRef` |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `fractionalize_asset` | `entry` | Locks an NFT, mints fungible shares to the caller |
| `recombine_asset` | `entry` | Burns all shares, returns the NFT to the caller |
| `metadata_object_address` | `#[view]` | Returns the fractionalization object address |

## Workflow

```
1. User owns NFT (Token Object)
2. Call fractionalize_asset(nft, supply=100)
   - NFT transferred to a new named object
   - NFT transfer disabled (locked)
   - 100 fungible tokens minted to user
3. User can trade fungible tokens freely
4. When one user holds all 100 tokens:
   - Call recombine_asset(metadata)
   - All 100 tokens burned
   - NFT transfer re-enabled
   - NFT returned to caller
```

## Important Notes

- Supply is set at fractionalization time and cannot change
- Decimals are set to 0 for simplicity (each share = 1 unit)
- The fungible asset metadata object persists forever (even after recombination), but no tokens will exist
- Only the holder of ALL shares can recombine

## Running Tests

```bash
aptos move test --dev --package-dir snippets/fractional-token
```

## Deploy

```bash
aptos move publish --named-addresses fraction_addr=default --package-dir snippets/fractional-token
```

## Related Examples

- [Liquid NFTs](../liquid-nfts/) -- Pool-based NFT liquidity (many NFTs, shared fungible token)
- [Composable NFTs](../composable-nfts/) -- Another advanced token pattern (composition)
- [FA Lockup / Escrow](../fa-lockup-example/) -- Locking fungible assets in escrow
