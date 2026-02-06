# Snipe Prevention (Anti-Snipe Token)

## Overview

Demonstrates how to implement snipe prevention for fungible asset token launches using dispatchable fungible assets. "Sniping" refers to bots or actors acquiring large amounts of tokens immediately at launch, often manipulating prices. This module prevents that by limiting how much any single wallet can receive until the protection is disabled by the contract owner.

## Difficulty

Intermediate

## Concepts Demonstrated

- **Dispatchable fungible assets**: Using deposit hooks to intercept and validate all token transfers
- **Enum types**: `AntisnipeData` enum with `Disabled` and `V1` variants for configuration state
- **Pattern matching**: Using `match` expressions to handle different enum variants
- **Resource indexing**: Move 2 syntax `FAData[@antisnipe]` for direct resource access
- **Object ownership checks**: Verifying the caller owns the code object for admin functions
- **Allowlist pattern**: Exempting specific addresses from transfer restrictions

## Key Structs

| Struct | Purpose |
|--------|---------|
| `FAData` | Main configuration stored on the FA metadata object, holds `ExtendRef` and antisnipe settings |
| `AntisnipeData` | Enum with `Disabled` (no restrictions) and `V1` (balance limit + allowlist) variants |

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `init_module` | `private` | Sets up dispatchable FA with deposit hook and initial antisnipe config (10000 limit) |
| `disable_antisnipe` | `entry` | Admin function to permanently disable snipe protection |
| `change_antisnipe_allowlisted_owners` | `entry` | Admin function to update the list of exempt addresses |
| `deposit` | `public` | Deposit hook called by FA framework, enforces antisnipe rules |
| `is_antisnipe_enabled` | `view` | Returns whether antisnipe is currently active |
| `get_antisnipe_amount` | `view` | Returns the balance limit if enabled |
| `get_antisnipe_allowlisted_owners` | `view` | Returns the allowlist if enabled |
| `get_antisnipe_data` | `view` | Returns the full antisnipe configuration |

## How It Works

1. **Deployment**: Contract is deployed as a code object (required for ownership checks)
2. **Initialization**: `init_module` registers a deposit hook with dispatchable FA framework
3. **Protection active**: When tokens are deposited:
   - Hook calculates what the recipient's new balance would be
   - If balance would exceed limit AND recipient not allowlisted, deposit is rejected
4. **Allowlist management**: Owner can add addresses to bypass the limit (e.g., liquidity pools)
5. **Disable**: Owner can permanently disable protection when launch period ends

## Antisnipe Logic

```
IF antisnipe is DISABLED:
    Allow deposit
ELSE (V1 enabled):
    new_balance = current_balance + deposit_amount
    IF new_balance <= antisnipe_amount OR owner in allowlist:
        Allow deposit
    ELSE:
        Reject with E_ANTISNIPE_ENABLED
```

## Deploy & Test

```bash
# Run unit tests
aptos move test --dev --package-dir snippets/snipe-prevention

# Compile only
aptos move compile --dev --package-dir snippets/snipe-prevention

# Deploy (requires code object deployment)
aptos move deploy-object --named-addresses antisnipe=default --package-dir snippets/snipe-prevention
```

## Related Examples

- [FA Lockup Example](../fa-lockup-example/) -- Time-locked fungible asset escrow with dispatchable FA
- [Fractional Token](../fractional-token/) -- Fungible asset representing fractional NFT ownership
- [Liquid NFTs](../liquid-nfts/) -- Converting between NFTs and fungible assets
