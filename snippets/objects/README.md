# Objects (Sticky Notes)

## Overview

Introduces the Aptos Object model by building a sticky note board. Demonstrates the differences between storing data as traditional resources vs. as objects, including how objects enable transferability, independent addresses, and extensibility.

## Difficulty

Beginner

## Concepts Demonstrated

- **Resources vs Objects**: Side-by-side comparison of storing `StickyNote` as a resource in a vector vs. as an independent object
- **Object creation**: `object::create_object_from_account` to create a new object
- **Object references**: `ExtendRef`, `TransferRef`, `DeleteRef` -- what each controls and when to store them
- **Soulbound objects**: Setting `can_transfer = false` to create non-transferable objects
- **Object transfer**: Using `object::transfer` to move objects between accounts
- **Resource groups**: `#[resource_group_member]` for co-locating data on objects

## Key Structs

| Struct | Purpose |
|--------|---------|
| `StickyNote` | A note with a message |
| `StickyNoteBoard` | Tracks resource-based sticky notes in a vector |
| `StickyNoteObjectBoard` | Tracks object-based sticky notes via `Object<StickyNote>` references |
| `ObjectController` | Stores `ExtendRef`, `TransferRef`, and `DeleteRef` for controlling an object |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `initialize_account` | `entry` | Creates both board types for an account |
| `create_note` | `entry` | Creates a resource-based sticky note |
| `create_object_note` | `entry` | Creates an object-based sticky note |
| `transfer_note` | `entry` | Transfers a resource note (requires removing from vector) |
| `transfer_note_object` | `entry` | Transfers an object note (more efficient for large notes) |

## Design Insight

Object-based sticky notes are cheaper to transfer than resource-based ones when the note content is large, because the object transfer only updates ownership metadata rather than moving the entire data structure.

## Deploy & Test

```bash
aptos move publish --named-addresses 0x42=default --package-dir snippets/objects
```

## Related Examples

- [Design Patterns: Autonomous Objects](../design-patterns/autonomous-objects/) -- Advanced object patterns with autonomous signers
- [Storage Patterns](../storage/) -- Comparing data structure choices for on-chain storage
