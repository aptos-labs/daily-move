# Design Pattern: Autonomous Objects

## Overview

Demonstrates two fundamental design patterns for working with Aptos Objects:

1. **Autonomous Object Pattern**: Creating an object at module deployment that can generate its own signer for programmatic actions without requiring the deployer to sign every transaction.
2. **Object Ownership Permission Pattern**: Ensuring only the owner of an object can perform privileged operations on it.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Named objects**: `object::create_named_object` for deterministic, non-deletable object addresses
- **ExtendRef**: Stored at creation time; used later to generate a signer via `generate_signer_for_extending`
- **TransferRef**: Controls whether an object can be transferred; supports soulbound (non-transferable) objects
- **DeleteRef**: Controls whether an object can be deleted; named and sticky objects cannot be deleted
- **init_module**: Runs once at contract deployment to set up the autonomous object
- **Ownership checks**: `object::is_owner` (direct owner) vs `object::owns` (recursive ownership check)

## Key Structs

| Struct | Purpose |
|--------|---------|
| `ObjectRefs` | Stores `ExtendRef`, optional `TransferRef`, and optional `DeleteRef` for controlling the object |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `init_module` | private | Creates the autonomous object on deployment |
| `fetch_object_address` | `public` | Returns the deterministic address of the object |
| `get_object_signer` | `public` | Returns the object's signer after verifying the caller is the owner |

## Design Patterns Explained

### Autonomous Object Pattern

```move
// At deployment: create a named object and store its ExtendRef
let constructor_ref = object::create_named_object(deployer, OBJECT_SEED);
let extend_ref = object::generate_extend_ref(&constructor_ref);

// Later: generate a signer from the stored ExtendRef
let object_signer = object::generate_signer_for_extending(&extend_ref);
// The object_signer can now perform actions (transfer assets, create sub-objects, etc.)
```

### Object Ownership Permission Pattern

```move
// Check that only the owner can get the signer
let caller_address = signer::address_of(caller);
let object = object::address_to_object<ObjectRefs>(object_address);
assert!(caller_address == object::owner(object), E_NOT_OBJECT_OWNER);
```

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_address=default --package-dir snippets/design-patterns/autonomous-objects
```

## Related Examples

- [Objects (Sticky Notes)](../../objects/) -- Introduction to the Object model
- [Controlled Mint](../../controlled-mint/) -- Uses object-owned collections for minting
- [Parallel NFTs](../../parallel-nfts/) -- Uses autonomous objects for public minting
