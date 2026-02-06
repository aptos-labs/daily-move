# Modifying NFTs

## Overview

Shows how to modify NFT properties after minting, including changing URIs, descriptions, and extending tokens/collections with custom data (like a points system). Demonstrates both the `AptosToken` convenience API and the lower-level custom token creation approach.

## Difficulty

Intermediate

## Concepts Demonstrated

- **AptosToken API**: High-level `aptos_token::create_collection` and `aptos_token::mint` with toggle flags
- **Custom token creation**: Lower-level `collection::create_fixed_collection` and `token::create` with manual ref management
- **MutatorRef**: Stored at creation; used to change token URI and description later
- **BurnRef**: Stored at creation; used to destroy tokens
- **Extending objects**: Adding new resources (like `CollectionPoints`, `TokenPoints`) to existing objects via `ExtendRef`
- **Permission models**: Owner OR creator can modify URIs; only creator can extend tokens with points

## Key Structs

| Struct | Purpose |
|--------|---------|
| `CollectionController` | Holds `ExtendRef` and `MutatorRef` for custom collections |
| `CollectionPoints` | Extension: adds a points pool to a collection |
| `TokenController` | Holds `ExtendRef`, `MutatorRef`, and `BurnRef` for custom tokens |
| `TokenPoints` | Extension: adds points to individual tokens |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `create_simple_collection` | `entry` | Creates a collection using the AptosToken API |
| `create_custom_collection` | `entry` | Creates a collection with manual ref storage |
| `add_points_to_collection` | `entry` | Extends a collection with a points system |
| `create_custom_token` | `entry` | Creates a token with stored mutator and burn refs |
| `change_custom_token_uri` | `entry` | Changes a token's URI (owner or creator) |
| `burn_custom_token` | `entry` | Burns a token, cleaning up all resources |
| `extend_token` | `entry` | Adds points from collection pool to a token (creator only) |

## Extension Pattern

Objects can be extended after creation by generating a signer from the stored `ExtendRef`:

```move
let controller = &CollectionController[collection_address];
let object_signer = object::generate_signer_for_extending(&controller.extend_ref);
move_to(&object_signer, CollectionPoints { total_points });
```

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/modifying-nfts
```

## Related Examples

- [Composable NFTs](../composable-nfts/) -- Dynamic NFTs that change image based on equipped items
- [Controlled Mint](../controlled-mint/) -- Creator-controlled minting with ref storage
- [Parallel NFTs](../parallel-nfts/) -- Public minting where owners can modify their own NFTs
