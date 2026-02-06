# Storage Patterns

## Overview

A comprehensive comparison of five on-chain data structures in Move, all implementing the same allowlist use case. Includes gas benchmarks for insertion, removal, and lookup operations at various scales. Also includes a shared `object_management` module demonstrating friend functions.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Vector**: Simple dynamic array; best for small datasets
- **SimpleMap**: Unsorted vector of key-value pairs; O(n) for all operations
- **Table**: Hash-based storage with O(1) operations but no iteration
- **SmartTable**: Hybrid bucketed table; O(bucket_size) operations with iteration
- **SmartVector**: Table-backed vector that scales past vector limits
- **Friend functions**: `public(friend)` visibility for shared utility modules
- **Object-based storage**: Using objects to hold data structures

## Data Structure Comparison

| Data Structure | Insert | Remove | Lookup | Iteration | Best For |
|---------------|--------|--------|--------|-----------|----------|
| **Vector** | O(1) append, O(n) insert | O(1) swap_remove, O(n) by value | O(1) by index, O(n) by value | Yes | Small datasets |
| **SimpleMap** | O(n) | O(n) | O(n) | Yes | Very small maps (<50 items) |
| **Table** | O(1) | O(1) | O(1) | **No** | Large datasets, no iteration needed |
| **SmartTable** | O(bucket) | O(bucket) | O(bucket) | Yes | Large datasets needing iteration |
| **SmartVector** | O(1) append | O(1) swap_remove, O(n) by value | O(1) by index, O(n) by value | Yes | Large ordered lists |

## Gas Benchmarks (293 items)

| Operation | Vector | SimpleMap | Table | SmartTable | SmartVector |
|-----------|--------|-----------|-------|------------|-------------|
| Init | 504 | 504 | 504 | 1505 | 504 |
| Add 293 | 6193 | 6957 | 149538 | 9723 | 7042 |
| Remove 293 | 2266 | 2361 | 2108 | 1884 | 5354 |
| Lookup 293 | 2268 | 2893 | 2090 | 1963 | 2394 |

> Note: Table has the highest insert cost because each entry creates a new storage slot.

## Modules

| Module | File | Description |
|--------|------|-------------|
| `object_management` | `object_management.move` | Shared utility for creating and managing objects (friend-only access) |
| `allowlist_vector` | `allowlist_vector.move` | Allowlist using `vector<address>` |
| `allowlist_simple_map` | `allowlist_simple_map.move` | Allowlist using `SimpleMap<address, u8>` |
| `allowlist_table` | `allowlist_table.move` | Allowlist using `Table<address, u8>` |
| `allowlist_smart_table` | `allowlist_smart_table.move` | Allowlist using `SmartTable<address, u8>` |
| `allowlist_smart_vector` | `allowlist_smart_vector.move` | Allowlist using `SmartVector<address>` |

## Key Design: Friend Functions

The `object_management` module uses `public(friend)` to share creation and permission logic across all allowlist modules without exposing it publicly:

```move
friend deploy_addr::allowlist_simple_map;
friend deploy_addr::allowlist_smart_table;
// ...

public(friend) fun create_object(caller: &signer): signer { ... }
public(friend) fun check_owner<T: key>(caller_address: address, object: Object<T>) { ... }
```

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/storage
```

## Related Examples

- [Data Structures (Min Heap)](../data-structures/heap/) -- Custom data structure implementation
- [Objects (Sticky Notes)](../objects/) -- Introduction to object-based storage
