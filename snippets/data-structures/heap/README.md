# Min Heap (Data Structures)

## Overview

Implements a min heap data structure in Move, providing a priority queue and heap sort algorithm. Includes formal verification specifications using the Move Prover to validate correctness of heap operations.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Custom data structures**: Building a min heap on top of Move's `vector`
- **Heap sort**: O(n log n) sorting algorithm using the heap
- **Formal verification**: `spec` blocks with `ensures`, `requires`, `aborts_if`, `aborts_with`
- **Spec functions**: `spec fun` for defining reusable verification helpers
- **Inline functions**: Using `inline fun` for zero-overhead helper functions

## Key Types

| Type | Description |
|------|-------------|
| `MinHeap` | A min heap backed by `vector<u64>` with `store` and `drop` abilities |

## Public API

| Function | Signature | Description |
|----------|-----------|-------------|
| `new` | `(): MinHeap` | Creates an empty heap |
| `from_vec` | `(vector<u64>): MinHeap` | Builds a heap from an unsorted vector |
| `to_vec` | `(MinHeap): vector<u64>` | Converts heap back to a vector |
| `insert` | `(&mut MinHeap, u64)` | Inserts a value maintaining heap property |
| `pop` | `(&mut MinHeap): u64` | Removes and returns the minimum value |
| `min` | `(&MinHeap): u64` | Returns the minimum without removing it |
| `size` | `(&MinHeap): u64` | Returns the number of elements |
| `is_empty` | `(&MinHeap): bool` | Returns true if empty |
| `heap_sort` | `(vector<u64>): vector<u64>` | Sorts a vector via heap sort |

## Complexity

| Operation | Time Complexity | Space Complexity |
|-----------|----------------|-----------------|
| `insert` | O(log n) | O(1) |
| `pop` | O(log n) | O(1) |
| `min` | O(1) | O(1) |
| `from_vec` | O(n log n) | O(1) |
| `heap_sort` | O(n log n) | O(n) |

## Running Tests

```bash
aptos move test --dev --package-dir snippets/data-structures/heap
```

## Running the Prover

```bash
aptos move prove --dev --package-dir snippets/data-structures/heap
```

## Related Examples

- [Storage Patterns](../../storage/) -- Comparison of other on-chain data structures
- [Prover (Payment Escrow)](../../prover/) -- More formal verification examples
