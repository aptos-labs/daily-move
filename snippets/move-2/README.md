# Move 2

All examples in this repository have been updated to use Move 2 syntax. The `move-2` directory previously held the heap example, which is now located at:

- [data-structures/heap/](../data-structures/heap/) -- Min heap implementation

## Move 2 Features Used Across Examples

| Feature | Description | Example Usage |
|---------|-------------|---------------|
| Receiver-style calls | `vec.length()` instead of `vector::length(&vec)` | All examples |
| Index notation | `Resource[addr]` instead of `borrow_global<Resource>(addr)` | Most examples |
| `for` loops | `for (i in 0..n) { ... }` | storage, controlled-mint, liquid-nfts |
| Enum types | `enum Escrow { Simple { ... }, TimeUnlock { ... } }` | fa-lockup-example |
| Pattern matching | `match (expr) { Variant { fields } => { ... } }` | fa-lockup-example |
