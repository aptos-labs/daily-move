# Prover (Payment Escrow)

## Overview

Demonstrates the Move Prover for formal verification through a payment escrow system (similar to Venmo). Users create escrow objects holding coins, and receivers can take, cancel, or transfer them. Every function includes formal `spec` blocks that the Move Prover can verify.

## Difficulty

Advanced

## Concepts Demonstrated

- **Move Prover**: `spec module { pragma verify = true; }` enables verification
- **Function specs**: `ensures`, `requires` postconditions and preconditions
- **Struct invariants**: Conditions that must always hold (e.g., coins.value > 0)
- **Spec schemas**: Reusable specification patterns (`CallerIsOwner`, `CallerIsCreatorOrOwner`)
- **Spec functions**: `spec fun get_escrow` for helper logic in specifications
- **aborts_if / aborts_with**: Specifying when and why functions abort
- **Object lifecycle**: Creating and deleting escrow objects with storage recovery

## Key Structs

| Struct | Purpose |
|--------|---------|
| `Escrow<CoinType>` | Holds escrowed coins, creator address, and delete ref |

## Struct Invariant

```move
spec Escrow {
    invariant coins.value > 0;      // Never an empty escrow
    invariant coins.value <= MAX_U64; // Within valid range
}
```

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `escrow_coins` | `entry` | Creates an escrow and transfers ownership to receiver |
| `take_escrow` | `entry` | Receiver withdraws coins (owner only) |
| `cancel_escrow` | `entry` | Returns coins to creator (owner or creator) |

## Specification Examples

### Function postcondition

```move
spec escrow_coins_inner {
    ensures amount == get_escrow(result).coins.value;
    ensures signer::address_of(caller) == get_escrow(result).creator;
}
```

### Reusable schema

```move
spec schema CallerIsOwner<CoinType> {
    escrow_object: Object<Escrow<CoinType>>;
    caller_address: address;
    let is_owner = object::is_owner(escrow_object, caller_address);
    ensures is_owner;
}
```

### Usage in function spec

```move
spec take_escrow {
    include CallerIsOwner<CoinType> {
        escrow_object,
        caller_address: signer::address_of(caller)
    };
}
```

## Running the Prover

```bash
aptos move prove --dev --package-dir snippets/prover
```

## Deploy

```bash
aptos move publish --named-addresses deployer=default --package-dir snippets/prover
```

## Related Examples

- [Data Structures (Min Heap)](../data-structures/heap/) -- Another example with formal verification specs
- [FA Lockup / Escrow](../fa-lockup-example/) -- More complex escrow with time locks
- [Struct Capabilities (Mailbox)](../struct-capabilities/) -- Escrow-like pattern for multi-asset transfers
