# Composable NFTs

## Overview

Builds a dynamic composable NFT system where a Face NFT can equip and unequip a Sailor Hat NFT. When the hat is equipped, the Face's image URI and description change to reflect the new look. Demonstrates object nesting, transfer locking, and dynamic token metadata.

## Difficulty

Advanced

## Concepts Demonstrated

- **Composable tokens**: One token (Face) can "contain" another (Hat) by transferring the hat to the face's address
- **Dynamic metadata**: Token URI and description change when hat is equipped/removed via `MutatorRef`
- **Transfer locking**: Equipped hats have their ungated transfer disabled so they can't be moved while worn
- **Object nesting**: The Hat object is transferred to the Face object's address, creating a parent-child relationship
- **Multiple collections**: Separate Face and Hat collections managed by a shared object owner
- **init_module**: Sets up both collections automatically on contract deployment

## Key Structs

| Struct | Purpose |
|--------|---------|
| `ObjectController` | Stores `ExtendRef` and optional `TransferRef` for controlling objects |
| `TokenController` | Stores `MutatorRef` and `BurnRef` for modifying token metadata |
| `Face` | Attached to face tokens; holds an optional reference to an equipped `Hat` |
| `Hat` | Attached to hat tokens; stores the hat type (e.g., "Sailor hat") |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `mint_face` | `entry` | Mints a new face NFT to the caller |
| `mint_sailor_hat` | `entry` | Mints a new sailor hat NFT to the caller |
| `add_hat` | `entry` | Equips a hat on a face, updating image and locking hat transfer |
| `remove_hat` | `entry` | Unequips the hat, restoring original image and re-enabling transfer |
| `face_wearing_hat` | `#[view]` | Returns the face wearing a given hat (if any) |
| `has_hat` | `#[view]` | Checks if a face has a hat equipped |
| `hat_address` | `#[view]` | Returns the equipped hat's address |

## Composition Flow

```
1. Mint Face (URI: face.png, description: "Face wifout hat")
2. Mint Hat  (URI: sailor_hat.png)
3. Add Hat to Face:
   - Transfer Hat object -> Face object address
   - Update Face URI -> face_with_hat.png
   - Update Face description -> "Face wif Sailor hat"
   - Disable Hat transfer (locked)
4. Remove Hat from Face:
   - Re-enable Hat transfer
   - Transfer Hat back to owner
   - Restore Face URI -> face.png
   - Restore Face description -> "Face wifout hat"
```

## Running Tests

```bash
aptos move test --dev --package-dir snippets/composable-nfts
```

## Deploy

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/composable-nfts
```

## Related Examples

- [Modifying NFTs](../modifying-nfts/) -- Simpler NFT modification (without composition)
- [Controlled Mint](../controlled-mint/) -- Creator-controlled minting pattern used here
- [Fractional Token](../fractional-token/) -- Another advanced token pattern (fractionalization)
