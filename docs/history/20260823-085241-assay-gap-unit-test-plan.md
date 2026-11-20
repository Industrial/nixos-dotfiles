# Assay Gap Inventory & Unit Test Plan

**Date:** 2026-08-23T085241Z
**Repo:** `/home/tom/.dotfiles`
**Goal:** Every tracked `*.nix` file gets unit-test coverage via a colocated `<stem>.assay.nix` suite, or an explicit documented exemption.

## Method

Scanned all `*.nix` files excluding `.git/` and `.cursor/`, skipped any ending in
`.assay.nix` (274 candidates), checked each directory for a sibling `<stem>.assay.nix`,
then filtered to git-tracked files only.

| Metric | Count |
|---|---|
| Non-assay `.nix` files found | 274 |
| Already covered by a sibling assay | 265 |
| Existing assay suites in repo | 258 |
| **Gaps (no complement)** | **9** |

### Excluded from scope (not tracked / generated state)

- `./.devenv/**`, `./hosts/drakkar/.devenv/**` — devenv bootstrap + nixpkgs-config snapshots, gitignored.
- `./.devenv.flake.nix` — devenv-generated, untracked.

## Gap List & Per-File Strategy

Convention: colocated suite imports the shared harness
(`common/assay/default.nix`) and runs via `devenv shell -- assay run .`.
Pattern reference: `features/media/seerr/default.assay.nix`.

### Priority 1 — Fleet service logic (highest value)

**1. `features/media/api-keys.nix`**
Pure data module (single source of truth for the five *arr API keys).
Suite: import the file; assert the attrset has exactly the keys
`prowlarr sonarr radarr readarr lidarr`; each value is a non-empty string
matching a plausible key shape (e.g. 32 hex chars). Never print values into
test output or failure messages — length/charset checks only.

**2. `features/media/arr-wiring.nix`** *(most complex)*
NixOS module defining two idempotent oneshot services
(`arr-api-key-seed`, `prowlarr-sync`) whose scripts are embedded
shell/python strings. Suite: import the module with stub `pkgs`/`lib`/`config`;
assert both systemd units are declared, `wantedBy` targets the right
multi-user target, unit ordering references the five *arr services, and the
seed script text embeds one `<app> <key>` line per app from api-keys.nix
(assert against the imported data module, not literals). If stubbing
`writeShellScript`/`writers.writePython3`, assert call shape (name + non-empty
text argument).

**3. `features/media/homarr/default.nix`**
OCI-container dashboard module (the rewritten container-based version — the
old broken `npm start` variant must never return). Suite: assert
`virtualisation.oci-containers.containers.homarr.image == "ghcr.io/homarr-labs/homarr:latest"`,
port mapping `"7575:7575"`, firewall opens 7575, tmpfiles rules create
`/data/services/homarr/data` and `/appdata`, and no `npm start` ExecStart
anywhere in the module output.

**4. `features/monitoring/prometheus-exporter/default.nix`**
Node exporter single-source-of-truth module. Suite: assert
`services.prometheus.exporters.node.enable == true`, `port == 9002`,
enabledCollectors is non-empty and contains `systemd`, and the enabled/disabled
collector sets are disjoint.

### Priority 2 — Packaging derivations

**5. `features/cli/usbtree/package.nix`**
`buildRustPackage` fetcher. Suite (eval-only, no build): instantiate with real
nixpkgs args; assert pname `usbtree`, version `0.1.1`, `mainProgram = "usbtree"`,
license mit, platforms linux, src rev `v0.1.1`. Full `nix-build` stays opt-in
(network fetch) — not part of default `assay run`.

**6. `features/ai/paperclip/package.nix`**
`writeShellApplication` CLI wrapper. Suite: assert name `paperclipai`,
`runtimeInputs` contains nodejs_22, script text includes the EUID root guard
and the pinned `paperclipai@2026.817.0`.

**7. `rust/tools/oomkiller/Cargo.nix`** *(generated, 2172 lines)*
Machine-generated cargo-lock artifact. **Proposed exemption:** no behavioural
suite. Minimal guard suite instead: file parses and evaluates to an attrset
whose top-level values carry `crateName`/`version` attributes. Mark as
"generated — regenerate, don't hand-edit" in this ledger.

### Priority 3 — Templates

**8–9. `.hermes/skills/hermes/hermes-plugin-development/templates/package.nix`**
and its intentional mirror copy at
`features/ai/hermes-agent/.hermes/skills/hermes/hermes-plugin-development/templates/package.nix`

**EXEMPTED by user directive (2026-08-23): `.hermes/` is off limits — no test
suites or helper files may be created under it, including the
`features/ai/hermes-agent/.hermes/` mirror.** These two template files remain
without assay complements by explicit decision; do not revisit without fresh
user approval.

## Execution Phases

1. **Phase 1 (P1):** four suites under `features/media/{api-keys,arr-wiring}.assay.nix`,
   `features/media/homarr/default.assay.nix`,
   `features/monitoring/prometheus-exporter/default.assay.nix`.
   Verify: `devenv shell -- assay run features/...` per suite.
2. **Phase 2 (P2):** three suites (usbtree, paperclip, Cargo.nix guard).
   Verify: same runner.
3. **Phase 3 (P3):** template suite(s) for both mirror paths. *(Superseded —
   see exemption above.)*
4. **Phase 4:** full gate `devenv shell -- assay run .` → exit 0;
   append completion note to this file.

## Acceptance Criteria

- Every tracked `*.nix` has a sibling `<stem>.assay.nix` OR appears in an
  explicit exemption section here.
- `devenv shell -- assay run .` passes with all new suites green.
- No API-key material appears in any test source, fixture, or failure message.

## Completion Note (2026-08-23)

Executed with user approval ("Approve — execute all phases"):

| Suite | Result |
|---|---|
| `features/media/api-keys.assay.nix` | 3/3 PASS |
| `features/media/arr-wiring.assay.nix` | 9/9 PASS |
| `features/media/homarr/default.assay.nix` | 7/7 PASS |
| `features/monitoring/prometheus-exporter/default.assay.nix` | 5/5 PASS |
| `features/cli/usbtree/package.assay.nix` | 8/8 PASS |
| `features/ai/paperclip/package.assay.nix` | 5/5 PASS |
| `rust/tools/oomkiller/Cargo.assay.nix` | 5/5 PASS |

Full gate: `assay run .` → **581/581 passed, 0 failed, 0 errored**.

Notes:
- Phase 3 was started before the user clarified `.hermes/` is off limits; the
  three created files were removed and the templates are recorded as exempted
  above.
- `homarr/default.assay.nix` had a committed version (d1445335) that was
  missing from the working tree at scan time; the rewritten suite preserves
  every original assertion and adds container-implementation guards.
- The two `.hermes` template files are the only tracked `.nix` files without
  an assay complement, by user directive.
