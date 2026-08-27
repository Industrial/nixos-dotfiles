# Assay v0.2.1 release + consumer-upgrade completion (2026-08-23)

Session continuation of the v0.2.0 release recorded in
`references/assay-v0.2.0-release-state.md`. Facts that were true at v0.2.0 and
remain structurally current (pipeline, workflows, gates, publish order) are NOT
duplicated here — see that file.

## What shipped in v0.2.1

- `feat(cli): add --version flag and bump workspace to 0.2.1` — clap `version`
  attr in `crates/assay/src/main.rs` `#[command(...)]`; reports from the crate
  version automatically (`assay 0.2.1`).
- Post-tag housekeeping commits: `chore: align inter-crate dep reqs and template
  pins to 0.2.1` + `fix: align nixdrv dep req to 0.2.1` — the v0.2.0 bump had
  left inter-crate dep reqs at `^0.2.0` (semver-valid but inconsistent).
- Final main: `ec53f59`; tag `v0.2.1` sits behind HEAD by design (housekeeping
  landed after the tag fired the release).

## Consumer fleet state after rollout

All consumers upgraded from 0.1.0 → 0.2.0 in this session, then benefited from
0.2.1 automatically where they track the repo head; static pin files were left
at their last-edited values unless edited:

| Repo | Mechanism | State |
|------|-----------|-------|
| ~/.dotfiles flake.lock | flake input rev | assay node moved once, scoped |
| ~/.dotfiles devenv.lock | devenv input rev | scoped via `devenv update assay` after unscoped incident |
| test-loco-webapp / solana-yield-optimizer / idclear monorepo `.cursor/nix/features/program-assay.nix` | version + SRI pin | bumped to 0.2.0 pins (uncommitted per user instruction) |
| assay repo `.cursor/nix/` + `contrib/cursor-setup/program-assay.nix` | wrapper-style templates (releaseHash = null) | default pin aligned to 0.2.1 in housekeeping commit |

## Verification-script lessons (v0.2.1 run)

- Fresh script per release: `/tmp/hermes-verify-assay-v021.sh` supersedes
  `/tmp/hermes-verify-assay-v020.sh` (the latter's assertions are stale by
  design). User declines `/tmp` cleanup; re-runs across turns for fresh
  evidence.
- Tag invariant: use `git merge-base --is-ancestor vX.Y.Z HEAD`, never
  equality — post-tag commits legitimately advance main.
- Chained `git commit ... | grep -E 'main \[' && git push` silently skipped the
  push when grep didn't match hook output; caught only because the verifier's
  "main synced" check failed. Run pushes as standalone commands.
- Verifier's "no stray <old-version>" check found 6 stale inter-crate dep reqs
  the manual bump missed — keep that check in every release verifier.
- First-run FAILs must be diagnosed as probe-bug vs code-bug before editing
  either; two of three first-run failures this session were script bugs
  (line-vs-match counting, over-assertion on wrapper-style templates).
