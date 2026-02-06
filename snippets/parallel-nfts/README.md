# Parallel NFT Minting

## Overview

Implements an Ethereum-style public NFT minting contract where anyone can mint from the collection. The collection is owned by an object (not a user account), enabling parallelized minting. Owners can customize their NFT's description and image, while the creator retains the ability to reset them.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Object-owned collections**: The collection is owned by a named object, not the deployer's account
- **Public minting**: Any user can call `mint` to create a new NFT
- **Mint gating**: Creator can enable/disable minting via `enable_mint` / `disable_mint`
- **Numbered tokens**: `token::create_numbered_token` produces `#1`, `#2`, etc.
- **Owner-mutable NFTs**: Token owner can change description and URI
- **Creator overrides**: Creator can reset token metadata to defaults
- **init_module**: Sets up the collection automatically on contract deployment

## Key Structs

| Struct | Purpose |
|--------|---------|
| `CollectionOwner` | Holds `ExtendRef` for the object that owns the collection |
| `CollectionRefs` | Holds `ExtendRef`, `MutatorRef`, and `mint_enabled` flag |
| `TokenRefs` | Holds `ExtendRef`, `MutatorRef`, `BurnRef` for each token |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `mint` | `public entry` | Mints a new numbered NFT to the caller |
| `enable_mint` / `disable_mint` | `public entry` | Creator toggles minting on/off |
| `change_token_description` | `public entry` | Owner changes their NFT's description |
| `change_token_uri` | `public entry` | Owner changes their NFT's image |
| `reset_token_description` | `public entry` | Creator resets description to default |
| `reset_token_uri` | `public entry` | Creator resets image to default |
| `collection_owner` | `#[view]` | Returns the collection owner object address |
| `collection_object` | `#[view]` | Returns the collection object address |

## Parallelization

By using `token::create_numbered_token`, each mint operation is independent and can run in parallel across validators. The numbered token approach uses atomic counters internally.

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/parallel-nfts
```

## Related Examples

- [Controlled Mint](../controlled-mint/) -- Creator-only minting with batch support
- [Modifying NFTs](../modifying-nfts/) -- More detailed NFT modification patterns
- [Design Patterns: Autonomous Objects](../design-patterns/autonomous-objects/) -- The underlying pattern for object-owned collections
