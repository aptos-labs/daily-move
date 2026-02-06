# Fungible Asset Lockup / Escrow

## Overview

Implements a time-locked escrow system for Fungible Assets (FAs). A lockup creator sets up an escrow, users deposit funds with optional time locks, and funds can be claimed by the creator, returned to users, or withdrawn by users after the lock period expires. Demonstrates Move 2 enum types, pattern matching, and dispatchable FA transfers.

## Difficulty

Advanced

## Concepts Demonstrated

- **Enum types** (Move 2): `Lockup` and `Escrow` use enum variants for different lockup strategies
- **Pattern matching** (Move 2): `match` expressions to handle different escrow types
- **Dispatchable fungible assets**: `dispatchable_fungible_asset::transfer` for FA-agnostic transfers
- **Fungible stores**: Creating standalone `FungibleStore` objects for escrow
- **SmartTable**: Mapping `EscrowKey` to escrow object addresses
- **Object lifecycle**: Creating, using, and deleting objects with storage deposit recovery
- **Time-based conditions**: Using `timestamp::now_seconds()` for lockup enforcement

## Key Types

| Type | Kind | Purpose |
|------|------|---------|
| `LockupRef` | struct | Stored in creator's account; points to the Lockup object |
| `Lockup` | enum (ST variant) | Holds escrow mappings, creator info, and control refs |
| `EscrowKey` | enum (FAPerUser variant) | Composite key: FA metadata + user address |
| `Escrow` | enum (Simple, TimeUnlock) | Per-user escrow with optional time lock |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `initialize_lockup` | `public entry` | Creates a new lockup for the caller |
| `escrow_funds_with_no_lockup` | `public entry` | Deposits funds without a time lock |
| `escrow_funds_with_time` | `public entry` | Deposits funds with a time lock |
| `claim_escrow` | `public entry` | Creator claims escrowed funds |
| `return_user_funds` | `public entry` | Creator returns funds to a user |
| `return_my_funds` | `public entry` | User withdraws their own funds (after lock expires) |
| `lockup_address` | `#[view]` | Returns the lockup object address for a creator |
| `escrowed_funds` | `#[view]` | Returns the escrowed amount for a user/FA pair |
| `remaining_escrow_time` | `#[view]` | Returns seconds until unlock for a user/FA pair |

## Enum & Match Pattern

```move
enum Escrow has key {
    Simple { original_owner: address, delete_ref: DeleteRef },
    TimeUnlock { original_owner: address, unlock_secs: u64, delete_ref: DeleteRef }
}

// Pattern matching on enum variants
match (&Escrow[escrow_address]) {
    Simple { original_owner, .. } => { *original_owner }
    TimeUnlock { original_owner, unlock_secs, .. } => {
        assert!(timestamp::now_seconds() >= *unlock_secs, E_UNLOCK_TIME_NOT_YET);
        *original_owner
    }
};
```

## Running Tests

```bash
aptos move test --move-2 --dev --package-dir snippets/fa-lockup-example
```

## Deploy

```bash
aptos move publish --named-addresses lockup_deployer=default --package-dir snippets/fa-lockup-example
```

## Related Examples

- [Prover (Payment Escrow)](../prover/) -- Simpler escrow with formal verification
- [Struct Capabilities (Mailbox)](../struct-capabilities/) -- Another custody/transfer pattern
- [Fractional Token](../fractional-token/) -- Locking up assets in objects
