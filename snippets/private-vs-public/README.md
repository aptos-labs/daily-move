# Private vs Public Functions

## Overview

Teaches function visibility in Move through a dice roll game. A player pays a fee to roll, and wins if they roll a 1. The example then shows how a "cheater" module can exploit `public entry` functions to avoid paying the fee when losing -- and why `entry` (private entry) functions prevent this.

## Difficulty

Beginner

## Concepts Demonstrated

- **Function visibility levels**:
  - `fun` (private): Only callable within the same module
  - `entry fun` (private entry): Callable as a transaction, but NOT from other modules
  - `public entry fun`: Callable as a transaction AND from other modules/scripts
  - `public fun`: Callable from other modules/scripts, but NOT directly as a transaction
- **Security implications**: Why `public entry` can be dangerous when fees or side effects should not be reverted
- **Transaction atomicity**: If any part of a transaction aborts, all state changes revert
- **Cheating via wrapping**: Calling a `public entry` function, then aborting if the result is unfavorable

## Module Structure

### `dice_roll` module (`dice_roll/`)

The main game module with four function variants demonstrating each visibility level.

| Function | Visibility | Can be a transaction? | Callable from other modules? | Cheatable? |
|----------|-----------|----------------------|----------------------------|------------|
| `play_game_internal` | private | No | No | No |
| `private_entry_fun` | `entry` | Yes | No | No |
| `play_game_public` | `public entry` | Yes | Yes | **Yes** |
| `play_game_internal_public` | `public` | No | Yes | **Yes** |

### `cheater` module (`cheater/`)

Demonstrates the exploit: wraps the public functions and aborts if the player loses, reverting the fee payment.

```move
// Cheat by aborting if we didn't win (reverts the fee payment)
dice_roll::play_game_public(caller);
let new_num_wins = dice_roll::num_wins(caller_address);
assert!(original_num_wins == new_num_wins, E_LOST); // abort if no new win
```

## Key Takeaway

Use `entry` (private entry) for functions where side effects (like fee payments) must persist regardless of outcome. Use `public entry` only when you want other contracts to be able to compose with your function.

## Deploy & Test

```bash
# Deploy the dice roll game
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/private-vs-public/dice_roll

# Deploy the cheater (separate package)
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/private-vs-public/cheater
```

## Related Examples

- [Error Codes](../error-codes/) -- How `abort` and `assert!` work
- [Struct Capabilities (Mailbox)](../struct-capabilities/) -- Another approach to access control
