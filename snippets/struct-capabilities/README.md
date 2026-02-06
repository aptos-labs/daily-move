# Struct Capabilities (Mailbox)

## Overview

Demonstrates capability-based access control through a mailbox system where users can send envelopes containing coins, legacy tokens, and objects to other users. Envelopes can be opened by the receiver or returned by the sender. Shows how Move's type system enforces safety through non-droppable, non-copyable structs.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Struct abilities and capabilities**: How `store`, `copy`, `drop` abilities control what can be done with a struct
- **Non-droppable structs**: `Envelope` cannot be dropped because it contains `Coin` and `Token`, preventing asset loss
- **Destructuring**: Breaking apart structs to access and properly handle their contents
- **SmartTable**: Used for mapping receivers to mailboxes
- **SmartVector**: Used for ordered mail storage within a mailbox
- **init_module**: Sets up the mailbox router as a named, non-transferable object on deployment
- **Named objects**: Deterministic addressing for the shared mailbox router

## Key Structs

| Struct | Abilities | Purpose |
|--------|-----------|---------|
| `MailboxRouter` | `key` | Global container holding all mailboxes; lives on a named object |
| `MailboxId` | `store, copy, drop` | Key for looking up a mailbox by receiver address |
| `Mailbox` | `store` | Contains a `SmartVector<Envelope>` of all mail |
| `Envelope` | `store` | Contains sender, note, coins, legacy tokens, and objects -- **cannot be copied or dropped** |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `send_mail` | `entry` | Sends an envelope with coins, objects, and legacy tokens to a receiver |
| `open_latest_envelope` | `entry` | Opens the most recent mail |
| `open_oldest_envelope` | `entry` | Opens the oldest mail |
| `open_envelope` | `entry` | Opens mail by index |
| `return_envelope` | `entry` | Returns mail to sender (only sender can do this) |
| `destroy_mailbox` | `entry` | Removes an empty mailbox to reclaim storage gas |

## Capability Pattern Explained

The `Envelope` struct cannot be dropped because `Coin<AptosCoin>` and `Token` lack the `drop` ability. This means the compiler forces you to properly handle every field:

```move
let Envelope {
    sender: _,           // Drop the address (has drop)
    note: _,             // Drop the option (has drop)
    coins,               // Must be deposited somewhere
    legacy_tokens,       // Must be deposited somewhere
    objects,             // Must be transferred
} = envelope;
```

If you forget to handle `coins` or `legacy_tokens`, the code will not compile -- preventing asset loss at the language level.

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/struct-capabilities
```

## Related Examples

- [Private vs Public](../private-vs-public/) -- Another approach to access control via function visibility
- [FA Lockup / Escrow](../fa-lockup-example/) -- Escrow pattern using fungible assets
- [Prover (Payment Escrow)](../prover/) -- Formally verified escrow with Move Prover
