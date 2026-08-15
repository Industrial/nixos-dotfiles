# Maestro CLI Binary Research

## The Two `maestro` Binaries

| Binary | Source | Version | What it is |
|--------|--------|---------|-------------|
| `/run/current-system/sw/bin/maestro` → `maestro-0.106.1` | NixOS system package (broken build) | `bun 1.3.11` from `maestro --version` | `autoPatchelfHook` + stdenv RPATH shrink corrupted the Bun-compiled release binary |
| `maestro` from ReinaMacCredy/maestro | GitHub release v0.106.1 | 0.106.1 | The actual local-first agent harness CLI |

### How to Tell Which You Have

```bash
# Check what kind of binary is on PATH
file $(which maestro)
# maestro --version → 0.106.x (not `bun 1.x`)
# maestro --help → "The harness OS for agent-generated codebases"
# `bun 1.x` + Bun usage text → Nix package used autoPatchelfHook or over-aggressive fixup
```

### Real maestro binary install

```bash
curl -fsSL https://raw.githubusercontent.com/ReinaMacCredy/maestro/main/scripts/install.sh | bash
# or pinned version:
MAESTRO_VERSION=0.106.1 curl -fsSL https://raw.githubusercontent.com/ReinaMacCredy/maestro/main/scripts/install.sh | bash
```

After install, confirm with `maestro --version` — should print `0.106.1` (not Bun's version string).

## maestro install Command (Skills Sync)

From README.md (ReinaMacCredy/maestro):

```
maestro install
```

Syncs bundled 6 skills (maestro-task, maestro-verify, maestro-handoff, maestro-design, maestro-mission, maestro-setup) into all available agent skill targets including `~/.hermes/skills/maestro`.

```
maestro skills install <source> --targets hermes
```

Installs a specific skill targeting Hermes only. The `maestro skills` subcommand also supports `--targets codex,claude,hermes,agentskills`.

## hermes skills search vs maestro CLI

The `hermes skills search maestro` returns skills-sh results (`skills-sh/tovimx/maestro-mobile`) that **do not install successfully** — the identifiers are truncated and `hermes skills inspect` fails to find them.

The actual maestro skills are bundled inside the maestro binary's repo at `skills/bundled/` and installed via `maestro install`, not `hermes skills install`.

## Skills Indexing Note

The hermes skills registry (`skills-sh/tovimx/maestro-*`) indexes a different maestro-mobile project (mobile UI testing?) unrelated to ReinaMacCredy/maestro. Do not confuse the two. When the user says "maestro" in the context of spec-to-ship workflow, they mean ReinaMacCredy/maestro.