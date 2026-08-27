# Assay Fleet Rollout — v0.2.1 (2026-08-23, second sweep)

Proof that fleet pin sweeps are RECURRING: the v0.2.0→v0.2.1 release shipped
mid-session and every static pin set in the morning sweep was stale by afternoon.

## Trigger

User: "Make sure again all our projects/systems use the latest version."

## Drift found (all behind, as predicted)

| Consumer | Mechanism | Was | Became |
|---|---|---|---|
| ~/.dotfiles/flake.lock | flake input | d02232a (v0.2.0) | ec53f59 (v0.2.1) |
| ~/.dotfiles/devenv.lock | devenv input | d02232a (v0.2.0) | ec53f59 (v0.2.1) |
| test-loco-webapp/.cursor/nix/features/program-assay.nix | version + SRI | 0.2.0 / qOHMVV… | 0.2.1 / zaejB1zfDQ214UJizIq9ds33BLpD7SrwL+USZaR9LvY= |
| solana-yield-optimizer/.cursor/nix/features/program-assay.nix | version + SRI | same drift | same fix |
| idclear/monorepo/.cursor/nix/features/program-assay.nix | version + SRI | same drift | same fix |
| assay repo templates (.cursor/nix + contrib/cursor-setup) | version only (wrapper-style) | already 0.2.1 (committed e9ede5b during release) | — |
| ~/.dotfiles/bin/ci/assay | reads rev from devenv.lock at runtime | auto-follows | — |

## New facts for this version

- v0.2.1 linux-gnu tarball: 2,235,516 bytes, SRI
  `sha256-zaejB1zfDQ214UJizIq9ds33BLpD7SrwL+USZaR9LvY=`
- Release commit: `ec53f593b967093433d96bf0c90708b9250bf865`
- `nix flake lock --update-input assay` and scoped `devenv update assay` both
  landed exactly one rev-line pair — no collateral input movement this time
  (contrast with the v0.2.0 sweep where bare `devenv update` dragged 4 unrelated
  inputs and had to be reverted).

## Functional proof matrix (v0.2.1 release binary via `nix run …/v0.2.1`)

| Suite | Result |
|---|---|
| ~/.dotfiles full tree (`assay run .`) | 598/598 passed |
| test-loco-webapp .cursor/nix | 117/117 passed |
| idclear/monorepo .cursor/nix | 138/138 passed |
| solana-yield-optimizer .cursor/nix | 135/136 (pre-existing stale `featureCount` expectation of 22; identical on v0.1.0/v0.2.0 — not a regression) |

## Notes

- Everything left uncommitted per user's standing instruction.
- Verifier script persisted at `/tmp/hermes-verify-assay-fleet-v021.sh`;
  parameterized copy now lives at skill `scripts/verify-fleet-pins.sh`.
