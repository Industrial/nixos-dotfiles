# deepsec

This directory holds the [deepsec](https://www.npmjs.com/package/deepsec)
config for the parent repo. Checked into git so teammates inherit
project context (auth shape, threat model, custom matchers); generated
scan output is gitignored.

Currently configured project: `dotfiles` (target: `..`).

## NixOS (Claude agent / `process`)

The `@anthropic-ai/claude-agent-sdk` optional native `claude` binary under
`node_modules` is built for generic Linux (glibc/musl FHS). **It does not run on
NixOS** (missing dynamic linker / wrong interpreter), which surfaces as:

`Claude Code native binary not found … claude-agent-sdk-linux-x64-musl/claude`

deepsec forwards **`CLAUDE_CODE_EXECUTABLE`** to the SDK (see its CLI). Fix:

1. **Recommended:** from this directory, use the flake dev shell (direnv loads
   it automatically if you allow `use flake`):

   ```bash
   nix develop
   # or: direnv allow   # once, if you use direnv
   ```

   That exports `CLAUDE_CODE_EXECUTABLE` to **`pkgs.claude-code`** from nixpkgs.
   The flake enables **`allowUnfree` only inside this dev shell** so the
   Anthropic `claude-code` package can be used.

   From the repo root you can also run: `nix develop ./.deepsec -c bash`.

2. **Manual:** install [claude-code](https://search.nixos.org/packages?query=claude-code)
   on your profile or system, then before `pnpm` / `bunx` deepsec:

   ```bash
   export CLAUDE_CODE_EXECUTABLE="$(command -v claude)"
   ```

Then `pnpm install` and run `pnpm deepsec process` (or `bunx deepsec process`) as usual.

## Setup

1. `pnpm install` — installs deepsec.
2. Add an AI Gateway / Anthropic / OpenAI token to `.env.local`. If
   you already have `claude` or `codex` CLI logged in on this
   machine, you can skip the token for non-sandbox runs (`process` /
   `revalidate` / `triage`); deepsec auto-detects and reuses the
   subscription. See
   `node_modules/deepsec/dist/docs/vercel-setup.md` after install.
3. Open the parent repo in your coding agent (Claude Code, Cursor, …)
   and have it follow `data/dotfiles/SETUP.md` to fill in
   `data/dotfiles/INFO.md`.

## Daily commands

```bash
pnpm deepsec scan
pnpm deepsec process     --concurrency 5
pnpm deepsec revalidate  --concurrency 5                  # cuts FP rate
pnpm deepsec export      --format md-dir --out ./findings
```

`--project-id` is auto-resolved while there's only one project in
`deepsec.config.ts`. Once you've added a second project, pass
`--project-id dotfiles` (or whichever id you want) explicitly.

`scan` is free (regex only). `process` is the AI stage (≈$0.30/file
on Opus by default). Run state goes to `data/dotfiles/`.

## Adding another project

To scan another codebase from this same `.deepsec/`:

```bash
pnpm deepsec init-project ../some-other-package   # path relative to .deepsec/
```

Appends an entry to `deepsec.config.ts` and writes
`data/<id>/{INFO.md,SETUP.md,project.json}`. Open the new SETUP.md
in your agent to fill in INFO.md.

## Layout

```
deepsec.config.ts        Project list (one entry per scanned repo)
data/dotfiles/
  INFO.md                Repo context — checked into git, hand-curated
  SETUP.md               Agent setup prompt — checked in, deletable
  project.json           Generated (gitignored)
  files/                 One JSON per scanned source file (gitignored)
  runs/                  Run metadata (gitignored)
  reports/               Generated markdown reports (gitignored)
AGENTS.md                Pointer for coding agents
.env.local               Tokens (gitignored)
```

## Docs

After `pnpm install`:

- Skill: `node_modules/deepsec/SKILL.md`
- Full docs: `node_modules/deepsec/dist/docs/{getting-started,configuration,models,writing-matchers,plugins,architecture,data-layout,vercel-setup,faq}.md`

Or browse on
[GitHub](https://github.com/vercel/deepsec/tree/main/docs).
