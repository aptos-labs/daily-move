# AGENTS.md

This file is the canonical guide for coding agents working in this repository. Human-oriented overview and example index: [README.md](README.md). Curated doc links: [llms.txt](llms.txt).

## Project overview

**daily-move** (`aptos-labs/daily-move`) is a collection of standalone **Move 2** packages under `snippets/`. Each package teaches one Aptos/Move concept. There is no workspace, root `Move.toml`, or shared build. Treat each directory that contains a `Move.toml` as its own package.

Do not publish these examples to mainnet. They are educational snippets, not production contracts.

## Documentation map

| File | Audience | Purpose |
|------|----------|---------|
| [README.md](README.md) | Humans | Overview, category index, named addresses |
| [AGENTS.md](AGENTS.md) | Coding agents | Commands, conventions, gotchas, CI |
| [CLAUDE.md](CLAUDE.md) | Claude Code | Symlink to `AGENTS.md` |
| [.github/copilot-instructions.md](.github/copilot-instructions.md) | GitHub Copilot | Symlink to `AGENTS.md` |
| [llms.txt](llms.txt) | Agents / crawlers | Curated links into example READMEs |
| `snippets/<example>/README.md` | Both | Per-example modules, entry points, compile/test/deploy |
| `.github/workflows/ci.yml` | CI | Exact compile/test loops GitHub runs |

When you add, rename, or remove an example, update **all** of: the snippet README, root README indexes + project tree, this file's package table, `llms.txt`, and CI if the package should compile or test.

## CLI rules (non-interactive)

- Run commands from the **repository root** unless a command `cd`s into a package.
- **Compile and test do not need an account.** Prefer them over `publish`.
- Never run `aptos init` without `--network` and `--assume-yes`. It prompts (and can hang) otherwise.
- Pass `--assume-yes` on any command that submits a transaction or deletes artifacts (`publish`, `deploy-object`, `move clean`).
- Newer Aptos CLI versions fail fast instead of prompting when stdin is not a TTY, or when `APTOS_NON_INTERACTIVE=1`. Still pass `--assume-yes` for mutating commands.
- First compile clones `aptos-framework` via git (can take a minute; may hit GitHub rate limits). Later compiles can add `--skip-fetch-latest-git-deps`.
- Do not commit `.aptos/` (private keys). It is gitignored.

Install the CLI: <https://aptos.dev/tools/aptos-cli/>

## Common commands

```bash
# Compile one package (no account)
aptos move compile --dev --package-dir snippets/<example>

# Test one package (implies compile)
aptos move test --dev --package-dir snippets/<example>

# Prove (heap and prover only; needs Move Prover / Boogie)
aptos move prove --dev --package-dir snippets/<example>

# Publish (needs a CLI profile; never mainnet from an agent)
aptos move publish --assume-yes --named-addresses <name>=default --package-dir snippets/<example>
```

**Exceptions** (do not copy the `--dev` pattern blindly):

| Package | Compile / test |
|---------|----------------|
| `snippets/fractional-token` | Do **not** use `--dev`. TokenMinter as a dev-dependency is broken. Use `--named-addresses fraction_addr=0x1337,minter=0x2337` |
| `snippets/snipe-prevention` | Compile/test with `--dev`. **Deploy with `aptos move deploy-object`**, not `publish` (ownership checks require a code object) |
| `snippets/objects` | Module address is numeric `0x42` (not a named address). Compile with `--dev`. Publishing requires a signer for `0x42`; compile is enough for most tasks |

### Compile every package (same set as CI, plus snipe-prevention)

```bash
packages=(
  snippets/composable-nfts
  snippets/controlled-mint
  snippets/data-structures/heap
  snippets/design-patterns/autonomous-objects
  snippets/error-codes
  snippets/fa-lockup-example
  snippets/liquid-nfts
  snippets/lootbox
  snippets/modifying-nfts
  snippets/objects
  snippets/parallel-nfts
  snippets/private-vs-public/dice_roll
  snippets/private-vs-public/cheater
  snippets/prover
  snippets/snipe-prevention
  snippets/storage
  snippets/struct-capabilities
)
for pkg in "${packages[@]}"; do
  echo "==> compile $pkg"
  (cd "$pkg" && aptos move compile --dev) || exit 1
done
(cd snippets/fractional-token && aptos move compile --named-addresses fraction_addr=0x1337,minter=0x2337) || exit 1
```

### Test packages that have unit tests

```bash
for pkg in \
  snippets/composable-nfts \
  snippets/controlled-mint \
  snippets/data-structures/heap \
  snippets/error-codes \
  snippets/fa-lockup-example \
  snippets/liquid-nfts \
  snippets/snipe-prevention
do
  echo "==> test $pkg"
  (cd "$pkg" && aptos move test --dev) || exit 1
done
(cd snippets/fractional-token && aptos move test --named-addresses fraction_addr=0x1337,minter=0x2337) || exit 1
```

CI today compiles most packages but **does not** compile `snipe-prevention`, and it tests only `heap`, `error-codes`, `fa-lockup-example`, and `controlled-mint`. If you change a package that has tests, run **that package's tests** even when CI does not.

## Package catalog

`snippets/move-2/` is documentation only (no `Move.toml`).

| Package dir | Named address | Module(s) | Tests | Notes |
|-------------|---------------|-----------|-------|-------|
| `snippets/error-codes` | `deploy_addr` | `deploy_addr::error_codes` | Yes (`--dev`) | |
| `snippets/objects` | _(none)_ | `0x42::sticky_note` | No | Numeric module address `0x42` |
| `snippets/private-vs-public/dice_roll` | `deploy_addr` | `deploy_addr::dice_roll` | No | Publish before `cheater` |
| `snippets/private-vs-public/cheater` | `deploy_addr` | `deploy_addr::cheater` | No | Local dep on `dice_roll` |
| `snippets/controlled-mint` | `deploy_addr` | `deploy_addr::controlled_mint` | Yes (`--dev`) | In CI test job |
| `snippets/data-structures/heap` | `deploy_addr` | `deploy_addr::min_heap_u64` | Yes (`--dev`) | Also `aptos move prove --dev`; in CI test job |
| `snippets/design-patterns/autonomous-objects` | `deploy_address` | `deploy_address::base` | No | Named address is `deploy_address`, not `deploy_addr` |
| `snippets/modifying-nfts` | `deploy_addr` | `deploy_addr::modify_nfts` | No | |
| `snippets/parallel-nfts` | `deploy_addr` | `deploy_addr::parallel_mint` | No | |
| `snippets/snipe-prevention` | `antisnipe` | `antisnipe::antisnipe_token` | Yes (`--dev`) | `deploy-object`; not in CI compile list |
| `snippets/storage` | `deploy_addr` | `deploy_addr::object_management`, `allowlist_*` | No | Six modules |
| `snippets/struct-capabilities` | `deploy_addr` | `deploy_addr::mailbox` | No | |
| `snippets/composable-nfts` | `deploy_addr` | `deploy_addr::composable_nfts` | Yes (`--dev`) | |
| `snippets/fa-lockup-example` | `lockup_deployer` | `lockup_deployer::fa_lockup` | Yes (`--dev`) | In CI test job |
| `snippets/fractional-token` | `fraction_addr`, `minter` | `fraction_addr::fractional_token` | Yes (explicit named addresses) | No `--dev` |
| `snippets/liquid-nfts` | `fraction_addr` | `fraction_addr::common`, `liquid_coin`, `liquid_coin_legacy`, `liquid_fungible_asset` | Yes (`--dev`) | |
| `snippets/lootbox` | `mystery_addr` | `mystery_addr::mystery_box` | No | `#[randomness]` on private `entry` |
| `snippets/prover` | `deployer` | `deployer::payment_escrow` | Prover only | `aptos move prove --dev` |

Fully qualified entry/view names use `named_address::module::function` (for example `deploy_addr::error_codes::throw_useful_error`).

## Move 2 and style conventions

Match neighboring files. All examples use **Move 2**:

- Receiver-style calls: `vector.length()` not `vector::length(&vector)`
- Index notation: `Resource[addr]` not `borrow_global<Resource>(addr)`
- `for (i in 0..n) { ... }` when looping
- Enums + `match` where the example already does (lockup, snipe-prevention)

Other rules visible in this repo:

- Error constants: `E_` prefix, unique `u64` starting at `1` (skip `0`), **`///` doc comments** (not `//`) so abort messages are readable
- Function visibility: `entry` (private entry) vs `public entry` has security implications — see `snippets/private-vs-public/`
- `#[randomness]` functions must be **private** `entry` (not `public`) so callers cannot compose and bias the result
- Abilities: `key` / `store` / `copy` / `drop` — do not add `drop` to structs that hold assets
- Named addresses in `Move.toml` stay `"_"` under `[addresses]` with a `[dev-addresses]` hex for `--dev`
- Prefer `deploy_addr` for new examples unless you have a reason to use a distinct name
- Keep each snippet focused on one topic; put prose in the package README, not only in `//` comments

Framework git deps: most packages use `aptos-labs/aptos-framework` @ `mainnet`. `fractional-token` still depends on `aptos-core` (and TokenMinter). Do not "simplify" that package onto `--dev` without checking compile.

## Adding or changing an example

1. Create or edit `snippets/<name>/` with `Move.toml` + `sources/*.move` (tests in `tests/` or `#[test]` in the module).
2. Write `README.md` using the same section order as existing snippets (see README "Example Documentation"). Include **Package**, **Module**, **Source**, **Named address**, **Compile**, **Deploy**, **Tests** (or omit Tests if none).
3. Use copy-pasteable commands from the repo root, with `--package-dir`, `--dev` or explicit `--named-addresses`, and `--assume-yes` on publish.
4. Register the example in [README.md](README.md) (category table, example index, project tree, named-address table), this catalog, [llms.txt](llms.txt), and `.github/workflows/ci.yml`.
5. Compile (and test if present) before you finish.

## Verification

Before claiming a Move change is done:

1. Compile the packages you touched.
2. Run tests if that package has them (see catalog).
3. If you changed `snippets/data-structures/heap` or `snippets/prover` and the Prover is installed, run `aptos move prove --dev --package-dir <dir>`.

Do not report compile/test success without actually running the command.

## Guardrails

- **Always** pass `--assume-yes` (and an explicit `--network` for `aptos init`) in this environment.
- **Always** keep named-address names in docs matching `Move.toml` (`deploy_address` vs `deploy_addr`, `lockup_deployer`, `mystery_addr`, `antisnipe`, `deployer`, `fraction_addr`).
- **Ask first** before adding dependencies, changing framework `rev`, or publishing to a public network.
- **Never** commit keys, `.aptos/`, or real account private material.
- **Never** rewrite an example into Move 1 syntax.
- **Never** replace `entry` with `public entry` (or the reverse) without reading `snippets/private-vs-public/` — that change is a security behavior change.
