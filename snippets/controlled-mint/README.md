# Controlled Mint

## Overview

Shows how to build a creator-controlled NFT minting system using Token V2 (Token Objects). The creator deploys the contract, creates a collection, then batch-mints numbered NFTs to multiple recipients. Demonstrates royalty configuration, named objects for deterministic addressing, and storing refs for future modifications.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Named objects**: Using `object::create_named_object` to create deterministic object addresses for the collection owner
- **Object-owned collections**: An object (not a user account) owns the collection, enabling programmatic minting
- **Numbered tokens**: `token::create_numbered_token` creates tokens like `#1`, `#2`, etc.
- **Royalty configuration**: Optional royalty setup with numerator/denominator/address
- **Batch minting**: Minting multiple NFTs in a single transaction to different recipients
- **Ref storage**: Storing `ExtendRef`, `MutatorRef`, `BurnRef` for future modifications

## Key Structs

| Struct | Purpose |
|--------|---------|
| `CollectionOwner` | Holds `ExtendRef` for the object that owns the collection |
| `CollectionRefs` | Holds `ExtendRef` and `MutatorRef` for modifying the collection |
| `TokenRefs` | Holds `ExtendRef`, `MutatorRef`, `BurnRef` for each minted token |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `create_collection` | `entry` | Creates a new unlimited collection with optional royalties |
| `mint` | `entry` | Batch mints numbered tokens to a list of destination addresses |

## Workflow

1. **Deploy** the contract
2. **Create a collection** via `create_collection` with name, description, URI, and optional royalty
3. **Mint tokens** via `mint` by passing vectors of descriptions, URIs, and destination addresses

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/controlled-mint
```

## Related Examples

- [Parallel NFT Minting](../parallel-nfts/) -- Public minting with parallelization
- [Modifying NFTs](../modifying-nfts/) -- How to change NFT metadata after minting
- [Composable NFTs](../composable-nfts/) -- Dynamic NFTs that change based on equipped items
