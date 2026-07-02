# Move 2

All examples in this repository use **Move 2** syntax. The `move-2` directory previously held the heap example, which now lives at [data-structures/heap/](../data-structures/heap/).

## Move 2 Features Used Across Examples

| Feature | Description | Examples |
|---------|-------------|----------|
| Receiver-style calls | `vec.length()` instead of `vector::length(&vec)` | All examples |
| Index notation | `Resource[addr]` instead of `borrow_global<Resource>(addr)` | Most examples |
| `for` loops | `for (i in 0..n) { ... }` | [storage](../storage/), [controlled-mint](../controlled-mint/), [liquid-nfts](../liquid-nfts/) |
| Enum types | `enum Escrow { Simple { ... }, TimeUnlock { ... } }` | [fa-lockup-example](../fa-lockup-example/), [snipe-prevention](../snipe-prevention/) |
| Pattern matching | `match (expr) { Variant { fields } => { ... } }` | [fa-lockup-example](../fa-lockup-example/), [snipe-prevention](../snipe-prevention/) |

## Related Examples

- [Min Heap (Data Structures)](../data-structures/heap/) — Custom data structure with formal verification
- [FA Lockup / Escrow](../fa-lockup-example/) — Enums and pattern matching in a production-style escrow
- [Snipe Prevention](../snipe-prevention/) — Enums, `match`, and Move 2 resource indexing
