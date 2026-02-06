# Error Codes

## Overview

Demonstrates best practices for defining and using error codes in Move on Aptos. Shows how doc comments (`///`) on constants produce human-readable error messages in transaction output, while regular comments (`//`) do not.

## Difficulty

Beginner

## Concepts Demonstrated

- **Doc comments vs regular comments**: Only `///` (doc comments) above a constant are included in error messages at runtime
- **Error code conventions**: Constants prefixed with `E_`, starting from `1` (skip `0`), each with a unique number
- **`abort` statement**: Immediately halts execution with an error code
- **`assert!` macro**: Conditional abort -- `assert!(condition, error_code)` aborts if the condition is false
- **Error classification**: Using `std::error::not_implemented()` and similar functions to add category information to error codes

## Key Functions

| Function | Visibility | Description |
|----------|-----------|-------------|
| `throw_error_code_only` | `entry` | Aborts with an error that has no doc comment (unhelpful message) |
| `throw_useful_error` | `entry` | Aborts with an error that has a doc comment (helpful message) |
| `throw_classified_error` | `entry` | Aborts with a classified error code (e.g., `0xc0003`) |
| `throw_if_false` | `entry` | Uses `assert!` to conditionally abort with a useful message |

## Error Code Pattern

```move
/// This error message will appear in the error message
const E_USEFUL_ERROR: u64 = 2;

// Two-slash comments do NOT appear in error messages
const E_ERROR_WITHOUT_MESSAGE: u64 = 1;
```

## Deploy & Test

```bash
aptos move publish --named-addresses deploy_addr=default --package-dir snippets/error-codes
```

## Related Examples

- [Private vs Public](../private-vs-public/) -- Uses error codes for access control checks
- [Objects](../objects/) -- Uses error codes for ownership validation
