# Rust Cursor Skills

Skills for Rust workspaces on **NixOS + devenv.nix**, aligned with `~/Code/rust` (`id_effect`, `forge`, `streamweave`, `solana-yield-optimizer`).

Primary learning path for effects: **[Typed Effects in Rust](https://industrial.github.io/id_effect/)** (id_effect mdBook).

## id_effect skills (book-aligned)

| Skill | Use when |
|-------|----------|
| [id-effect-hard-rules](id-effect-hard-rules/SKILL.md) | Every write/review — non-negotiable rules |
| [id-effect-quick-ref](id-effect-quick-ref/SKILL.md) | Fast snippets + routing to deeper skills |
| [id-effect-foundations](id-effect-foundations/SKILL.md) | Part I — `Effect<A,E,R>`, `effect!`, laziness |
| [id-effect-environment](id-effect-environment/SKILL.md) | Part II — tags, layers, services, `NeedsX` |
| [id-effect-service-layout](id-effect-service-layout/SKILL.md) | **Mandatory** — `{Name}Service` / `Live` / `Mock` three-file layout |
| [id-effect-integrations](id-effect-integrations/SKILL.md) | Tokio, platform, reqwest, axum, config, logger, rpc |
| [id-effect-real-programs](id-effect-real-programs/SKILL.md) | Part III — errors, fibers, resources, scheduling |
| [id-effect-cli](id-effect-cli/SKILL.md) | Part III ch16 — `clap`, `id_effect_cli`, `ExitCode` |
| [id-effect-advanced](id-effect-advanced/SKILL.md) | Part IV — STM, streams, schema |
| [id-effect-testing](id-effect-testing/SKILL.md) | Part IV ch15 — `run_test`, mocks, coverage |
| [id-effect-migration](id-effect-migration/SKILL.md) | Appendix B — async → Effect conversion |
| [id-effect-review](id-effect-review/SKILL.md) | PR review checklist |
| [id-effect-construct-reference](id-effect-construct-reference/SKILL.md) | Exhaustive BAD/GOOD per construct (deep reference) |

### id_effect decision tree

```
New to id_effect?     → hard-rules → foundations → book Part I
Wiring DI / layers?     → hard-rules → environment → service-layout
HTTP server / CLI?      → integrations → cli
Fibers / retries?       → real-programs
STM / streams / schema? → advanced
Writing tests?          → testing
Converting async code?  → migration
Reviewing a PR?         → review (+ hard-rules)
Quick snippet?          → quick-ref
Obscure API / law test? → construct-reference
devenv / Moon / Nix?    → rust-devenv
```

### Deprecated aliases

| Old | Replacement |
|-----|-------------|
| `id-effect-fundamentals` / `effect-rs-fundamentals` | Part skills + `id-effect-construct-reference` |
| `id-effect-patterns` / `effect-rs-patterns` | `id-effect-quick-ref` |

## Toolchain

| Skill | Use when |
|-------|----------|
| [rust-devenv](rust-devenv/SKILL.md) | `devenv.nix`, NixOS linker/bindgen, Moon, sccache, coverage gates |

## Cross-links

- **Devenv first:** `devenv shell --` for all cargo/moon commands.
- **Run at edge:** domain returns `Effect<A,E,R>`; `run_blocking` / `run_main` in binaries; `run_test` in tests.
- **Gates:** Moon `:format`, `:check`, `:clippy`, `:test`, `:coverage`, `:audit` — see `id_effect/moon.yml`.

## Source repos

| Repo | Notable choices |
|------|-----------------|
| `id_effect` | nightly + `rustc-dev`, mdBook, 95% coverage, `examples/cli-minimal` |
| `forge` | stable, Playwright LD_LIBRARY_PATH |
| `streamweave` | minimal stable + treefmt/prek |
| `solana-yield-optimizer` | bindgen, `EFFECT.md`, `*_service` / `*_live` / `*_mock` file split |
