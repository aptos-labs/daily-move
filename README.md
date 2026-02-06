# Aptos Move Examples

A curated collection of Move language examples for the [Aptos](https://aptos.dev) blockchain. Each snippet demonstrates a specific concept, design pattern, or feature of Move on Aptos, written using **Move 2** syntax.

> **Originally created by [@gregnazario](https://twitter.com/gregnazario)** as a series of educational tweets on learning Move piece by piece.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Examples by Category](#examples-by-category)
  - [Beginner](#beginner)
  - [Intermediate](#intermediate)
  - [Advanced](#advanced)
- [Example Index](#example-index)
- [Concepts Covered](#concepts-covered)
- [Project Structure](#project-structure)

---

## Overview

This repository contains standalone Move snippets that each focus on a specific topic. The examples progress from basic language features (error codes, structs, objects) through intermediate patterns (NFT minting, storage data structures) to advanced use cases (composable NFTs, liquid tokens, formal verification).

All examples use **Move 2** syntax, including:
- Receiver-style function calls (`vector.length()` instead of `vector::length(&vector)`)
- Index notation for resource access (`Resource[address]` instead of `borrow_global<Resource>(address)`)
- Enum types
- Pattern matching with `match`
- `for` loops

---

## Prerequisites

- [Aptos CLI](https://aptos.dev/tools/aptos-cli/) installed
- Basic familiarity with Move language concepts (modules, structs, resources, signers)
- An Aptos account (can be created via `aptos init`)

---

## Quick Start

### Deploy an example

```bash
# Set your address
MY_ADDR=0x12345
aptos move publish --named-addresses deploy_addr=$MY_ADDR --package-dir snippets/<example-dir>
```

### Using a CLI profile

```bash
aptos init --profile my-profile
aptos move publish --profile my-profile --named-addresses deploy_addr=my-profile --package-dir snippets/<example-dir>
```

### Using the default profile

```bash
aptos init
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/<example-dir>
```

### Run tests for an example

```bash
aptos move test --dev --package-dir snippets/<example-dir>
```

After deploying, interact with your contract via the [Aptos Explorer](https://explorer.aptoslabs.com/account/<ADDRESS>/modules/run?network=devnet).

---

## Examples by Category

### Beginner

| Example | Directory | Description |
|---------|-----------|-------------|
| [Error Codes](snippets/error-codes/) | `snippets/error-codes/` | How to define and use error codes with doc comments for readable error messages |
| [Objects (Sticky Notes)](snippets/objects/) | `snippets/objects/` | Introduction to the Aptos Object model, comparing resources vs objects |
| [Private vs Public Functions](snippets/private-vs-public/) | `snippets/private-vs-public/` | Function visibility and why it matters for security (with a cheater example) |

### Intermediate

| Example | Directory | Description |
|---------|-----------|-------------|
| [Controlled Mint](snippets/controlled-mint/) | `snippets/controlled-mint/` | Creator-controlled NFT minting with royalty support |
| [Data Structures (Min Heap)](snippets/data-structures/heap/) | `snippets/data-structures/heap/` | Min heap implementation with formal verification specs |
| [Design Patterns: Autonomous Objects](snippets/design-patterns/autonomous-objects/) | `snippets/design-patterns/autonomous-objects/` | Creating objects that can act autonomously via extend refs |
| [Modifying NFTs](snippets/modifying-nfts/) | `snippets/modifying-nfts/` | How to modify NFT properties, URIs, and extend collections with custom data |
| [Parallel NFT Minting](snippets/parallel-nfts/) | `snippets/parallel-nfts/` | Parallelized NFT minting using object-owned collections |
| [Storage Patterns](snippets/storage/) | `snippets/storage/` | Comparison of Vector, SimpleMap, Table, SmartTable, and SmartVector with gas benchmarks |
| [Struct Capabilities (Mailbox)](snippets/struct-capabilities/) | `snippets/struct-capabilities/` | Using structs for capability-based access control in a mailbox system |

### Advanced

| Example | Directory | Description |
|---------|-----------|-------------|
| [Composable NFTs](snippets/composable-nfts/) | `snippets/composable-nfts/` | Dynamic composable NFTs where a Face can equip/unequip a Hat, changing the token image |
| [FA Lockup / Escrow](snippets/fa-lockup-example/) | `snippets/fa-lockup-example/` | Time-locked fungible asset escrow with dispatchable transfers |
| [Fractional Token](snippets/fractional-token/) | `snippets/fractional-token/` | Fractionalizing a digital asset into fungible tokens and recombining them |
| [Liquid NFTs](snippets/liquid-nfts/) | `snippets/liquid-nfts/` | NFT liquidity pools using Coin, Legacy Token, and Fungible Asset standards |
| [Lootbox / Mystery Box](snippets/lootbox/) | `snippets/lootbox/` | On-chain mystery boxes using Aptos randomness, supporting coins, FAs, and NFTs |
| [Prover (Payment Escrow)](snippets/prover/) | `snippets/prover/` | Formal verification with the Move Prover on a payment escrow contract |

---

## Example Index

| # | Example | Key Concepts | Move 2 Features Used | Has Tests |
|---|---------|-------------|---------------------|-----------|
| 1 | [error-codes](snippets/error-codes/) | Error codes, doc comments, `abort`, `assert!` | Receiver style | No |
| 2 | [objects](snippets/objects/) | Object model, resources vs objects, `ExtendRef`, `DeleteRef`, `TransferRef` | Receiver style, index notation | No |
| 3 | [private-vs-public](snippets/private-vs-public/) | Function visibility (`public`, `public entry`, `entry`, private), security | Receiver style, index notation | No |
| 4 | [controlled-mint](snippets/controlled-mint/) | Token V2 minting, collections, royalties, named objects | Receiver style, index notation, `for` loops | No |
| 5 | [data-structures/heap](snippets/data-structures/heap/) | Min heap, heap sort, formal verification specs | Receiver style, `for` loops | Yes |
| 6 | [design-patterns/autonomous-objects](snippets/design-patterns/autonomous-objects/) | Autonomous object pattern, ownership permission pattern | Receiver style, index notation | No |
| 7 | [modifying-nfts](snippets/modifying-nfts/) | Mutable NFTs, `MutatorRef`, `BurnRef`, extending objects | Receiver style, index notation | No |
| 8 | [parallel-nfts](snippets/parallel-nfts/) | Parallelized minting, object-owned collections, numbered tokens | Receiver style, index notation | No |
| 9 | [storage](snippets/storage/) | Vector, SimpleMap, Table, SmartTable, SmartVector, gas comparison | Receiver style, index notation, `for` loops | No |
| 10 | [struct-capabilities](snippets/struct-capabilities/) | Capability pattern, `SmartTable`, `SmartVector`, envelopes | Receiver style, index notation | No |
| 11 | [composable-nfts](snippets/composable-nfts/) | Composable tokens, dynamic URIs, transfer locking | Receiver style, index notation | Yes |
| 12 | [fa-lockup-example](snippets/fa-lockup-example/) | Fungible asset escrow, time locks, enum types, `match` | Receiver style, index notation, enums, `match`, `for` loops | Yes |
| 13 | [fractional-token](snippets/fractional-token/) | Fractionalization, fungible assets, primary stores | Receiver style, index notation | Yes |
| 14 | [liquid-nfts](snippets/liquid-nfts/) | Liquidity pools, Coin vs FA, legacy tokens, pseudorandom | Receiver style, index notation, `for` loops | Yes |
| 15 | [lootbox](snippets/lootbox/) | Randomness API, multi-asset boxes, soulbound tickets | Receiver style, index notation, `for` loops | No |
| 16 | [prover](snippets/prover/) | Move Prover, formal specs, invariants, schemas | Receiver style, index notation | No |

---

## Concepts Covered

### Language Features
- **Error Codes**: Named constants with doc comments for readable abort messages
- **Function Visibility**: `public`, `public entry`, `entry`, private, `public(friend)`, `inline`
- **Structs & Resources**: `has key`, `has store`, `has copy`, `has drop` abilities
- **Generics & Phantom Types**: `phantom` type parameters for type-safe wrappers
- **Enum Types**: Move 2 enum declarations with variant matching
- **Pattern Matching**: `match` expressions for enums and destructuring

### Aptos Framework
- **Object Model**: `ConstructorRef`, `ExtendRef`, `DeleteRef`, `TransferRef`, object creation, named/sticky objects
- **Token V2 (Token Objects)**: Collections, tokens, `MutatorRef`, `BurnRef`, numbered tokens
- **Fungible Assets**: `Metadata`, `FungibleStore`, primary stores, mint/burn/transfer
- **Coin (Legacy)**: `coin::initialize`, mint/burn capabilities, `CoinStore`
- **Randomness**: `randomness::u64_range` for on-chain random number generation
- **Timestamps**: `timestamp::now_seconds()`, `timestamp::now_microseconds()`

### Design Patterns
- **Autonomous Objects**: Objects that can act as signers via `ExtendRef` for programmatic actions
- **Object Ownership Permission**: Checking `object::is_owner` or `object::owns` before granting access
- **Capability Pattern**: Using structs as capabilities to gate access to privileged operations
- **Named Objects**: Deterministic object addresses via `object::create_named_object`
- **Collection-Owned Minting**: Object-owned collections that allow parallelized or public minting
- **Dynamic NFTs**: Changing token metadata (URI, description) based on state changes
- **Composable NFTs**: Nesting objects (equipping items) and reflecting changes in metadata
- **Fractionalization**: Converting a single NFT into fungible shares and back
- **Escrow Patterns**: Time-locked and simple escrow using objects and fungible stores

### Storage & Data Structures
- **Vector**: O(1) append, O(n) lookup by value; best for small datasets
- **SimpleMap**: O(n) operations; stored as unsorted vector of key-value pairs
- **Table**: O(1) operations; no iteration; each entry stored separately on-chain
- **SmartTable**: O(bucket_size) operations; hybrid of vector and table with bucketing
- **SmartVector**: O(1) append; scales past vector limits using table-backed buckets
- **Min Heap**: Priority queue with O(n log n) sort, O(log n) insert/pop

### Formal Verification
- **Move Prover**: `spec` blocks, `ensures`, `requires`, `aborts_if`, `aborts_with`
- **Invariants**: Struct invariants that must always hold
- **Schemas**: Reusable specification patterns

---

## Project Structure

```
snippets/
├── composable-nfts/          # Dynamic composable Face + Hat NFTs
│   ├── Move.toml
│   └── sources/
│       └── composable_nfts.move
├── controlled-mint/          # Creator-controlled batch NFT minting
│   ├── Move.toml
│   └── sources/
│       └── controlled_mint.move
├── data-structures/
│   └── heap/                 # Min heap with formal verification
│       ├── Move.toml
│       ├── sources/
│       │   └── min_heap_u64.move
│       └── tests/
│           └── min_heap_u64_tests.move
├── design-patterns/
│   └── autonomous-objects/   # Autonomous object design pattern
│       ├── Move.toml
│       └── sources/
│           └── base.move
├── error-codes/              # Error code best practices
│   ├── Move.toml
│   └── sources/
│       └── error_codes.move
├── fa-lockup-example/        # Fungible asset time-locked escrow
│   ├── Move.toml
│   └── sources/
│       └── lockup.move
├── fractional-token/         # NFT fractionalization into fungible tokens
│   ├── Move.toml
│   ├── sources/
│   │   └── fractional_token.move
│   └── tests/
│       ├── common_tests.move
│       └── fractional_token_tests.move
├── liquid-nfts/              # NFT liquidity pools (3 implementations)
│   ├── Move.toml
│   └── sources/
│       ├── common.move
│       ├── liquid_coin.move
│       ├── liquid_coin_legacy.move
│       └── liquid_fungible_asset.move
├── lootbox/                  # On-chain mystery boxes with randomness
│   ├── Move.toml
│   └── sources/
│       └── mystery_box.move
├── modifying-nfts/           # Mutable NFT properties and extension
│   ├── Move.toml
│   └── sources/
│       └── modify_nfts.move
├── parallel-nfts/            # Parallelized public NFT minting
│   ├── Move.toml
│   └── sources/
│       └── parallel_mint.move
├── private-vs-public/        # Function visibility & security
│   ├── cheater/
│   │   ├── Move.toml
│   │   └── sources/
│   │       └── cheater.move
│   └── dice_roll/
│       ├── Move.toml
│       └── sources/
│           └── dice_roll.move
├── prover/                   # Formal verification with Move Prover
│   ├── Move.toml
│   └── sources/
│       └── payment_escrow.move
├── storage/                  # Data structure comparison with gas benchmarks
│   ├── Move.toml
│   └── sources/
│       ├── allowlist_simple_map.move
│       ├── allowlist_smart_table.move
│       ├── allowlist_smart_vector.move
│       ├── allowlist_table.move
│       ├── allowlist_vector.move
│       └── object_management.move
└── struct-capabilities/      # Capability-based mailbox system
    ├── Move.toml
    └── sources/
        └── mailbox.move
```

---

## Named Addresses

Different examples use different named addresses in their `Move.toml`. When deploying, substitute the appropriate address:

| Named Address | Used By |
|--------------|---------|
| `deploy_addr` | Most examples (error-codes, composable-nfts, controlled-mint, modifying-nfts, parallel-nfts, storage, struct-capabilities) |
| `deploy_address` | design-patterns/autonomous-objects |
| `fraction_addr` | fractional-token, liquid-nfts |
| `mystery_addr` | lootbox |
| `lockup_deployer` | fa-lockup-example |
| `deployer` | prover |
| `0x42` | objects (sticky-note) |

---

## License

See [LICENSE](LICENSE) for details.
