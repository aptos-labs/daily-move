# Lootbox / Mystery Box

## Overview

Implements an on-chain mystery box system using the Aptos randomness API. A registry holds mystery boxes that can contain coins, fungible assets, legacy tokens, and digital assets. Soulbound tickets are minted to users, who redeem them to receive a randomly selected box.

## Difficulty

Advanced

## Concepts Demonstrated

- **Aptos Randomness API**: `#[randomness]` attribute + `randomness::u64_range` for secure on-chain random selection
- **Multi-asset boxes**: A single box can hold coins (up to 3 types), fungible assets, legacy tokens, and digital assets
- **Soulbound tokens**: Tickets are non-transferable (transfer disabled after creation)
- **Numbered tickets**: Using `token::create_numbered_token` for unique ticket naming
- **Box lifecycle**: Create -> store in registry -> mint ticket -> redeem ticket -> open box -> delete box
- **Allowlists**: Optional restriction on who can add boxes to the registry

## Key Structs

| Struct | Purpose |
|--------|---------|
| `MysteryBoxRegistry` | Global registry holding boxes and an optional add-allowlist |
| `Ticket` | Soulbound token that can be redeemed for a random box |
| `MysteryBox` | Container holding type flags and control refs |
| `CoinBox<CoinType>` | Holds coins of a specific type |
| `FungibleAssetBox` | Holds fungible assets via `FungibleStore` delete refs |
| `LegacyTokenBox` | Holds legacy (V1) tokens |
| `DigitalAssetBox` | Holds digital assets (Token Objects) |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `create_registry` | `public entry` | Creates a mystery box registry with a ticket collection |
| `mint_tickets` | `public entry` | Mints soulbound tickets to receivers |
| `create_coin_box` | `public entry` | Creates a box containing a single coin type |
| `create_fa_box` | `public entry` | Creates a box containing a fungible asset |
| `create_legacy_token_box` | `public entry` | Creates a box containing a legacy token |
| `create_digital_asset_box` | `public entry` | Creates a box containing a digital asset |
| `create_multi_box` | `public entry` | Creates a box containing multiple asset types |
| `open_box` | `entry` (private, `#[randomness]`) | Redeems a ticket and opens a random box |

## Randomness Pattern

The `open_box` function uses the `#[randomness]` attribute, which means:
- It must be a **private** entry function (prevents composition that could game randomness)
- It uses `randomness::u64_range(0, num_boxes)` for secure random selection

```move
#[randomness]
entry fun open_box<CoinType0, CoinType1, CoinType2>(
    caller: &signer,
    ticket: Object<Ticket>
) {
    // ...
    let index = randomness::u64_range(0, num_boxes);
    let box_object = registry.boxes.swap_remove(index);
    // ...
}
```

## Deploy

```bash
aptos move publish --named-addresses mystery_addr=default --package-dir snippets/lootbox
```

## Related Examples

- [Liquid NFTs](../liquid-nfts/) -- Pool-based random distribution (pseudorandom approach)
- [FA Lockup / Escrow](../fa-lockup-example/) -- Escrow pattern for fungible assets
- [Struct Capabilities (Mailbox)](../struct-capabilities/) -- Another multi-asset transfer pattern
