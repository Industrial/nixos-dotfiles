# Rust Replacement Candidates (fleet audit 2026-08)

Session: user asked which dotfiles components would benefit most from a Rust
rewrite, explicitly excluding bin/ plumbing and small-script territory.
Findings in priority order.

## 1. arr-wiring reconciler — highest value

- `features/media/arr-wiring.nix` (two oneshot services):
  - `arr-api-key-seed`: edits each *arr app's `/data/services/<app>/config.xml`
    with grep/sed regexes (`features/media/arr-wiring.nix:29`), infers restart
    needs via string matching, then stop/sleep/start loops.
  - `prowlarr-sync` (`features/media/arr-wiring.nix:65`):
    `pkgs.writers.writePython3` REST reconciler against Prowlarr/Sonarr/Radarr/
    Readarr/Lidarr; config passed via TARGETS/CATEGORIES JSON env vars; hand-
    rolled wait-for-ready polling loop. pycodestyle enforced at BUILD time by
    the writer, so every tweak risks failing the whole eval.
- Rust shape: quick-xml for config.xml (real parsing, not regex), reqwest +
  retry for the Prowlarr API, serde structs for the application schema,
  idempotent reconcile with diffs. Single static binary → systemd ExecStart.
- Est ~1–2k lines, one crate `rust/tools/arr-wire`.

## 2. Alert bridge + active probes

- Current state: `features/monitoring/prometheus/default.nix` ships
  Alertmanager whose only receiver posts to `http://127.0.0.1:5001/` with
  example.com SMTP — nothing listens. Fleet effectively has zero alerting.
- Known ops pain (skill-documented): unit state lies (oci-containers report
  inactive while serving; grafana stayed failed across green deploys because
  unchanged units aren't restarted).
- Rust shape: axum/tiny-http server accepting Alertmanager webhooks → format →
  Telegram bot API; plus concurrent TCP/HTTP probes of all ten mimir services
  writing pass/fail to node_exporter textfile dir so alerts fire on real
  app-down rather than systemctl state.

## 3. vulnix replacement

- `bin/ci/vulnix` is a 38-line inline `nix-shell -E` Python contraption keeping
  abandoned Python tooling alive just for CI.
- Rust shape: parse `nix path-info --json` / closure output, normalise
  versions, batch-query OSV API, cache results, exit nonzero on findings;
  also usable as a systemd timer beyond pre-push CI.

## 4. Backups — gap, conditional candidate

- No borg/restic/rustic/sanoid anywhere (features/, hosts/, profiles/).
  Mimir holds all persistent state at `/data/services` with NFS exports and no
  backup coverage at all.
- If coverage gets added anyway, prefer **rustic** (Rust, restic-format,
  single static binary) over introducing Go's restic or Python's borg —
  matches fleet's buildRustPackage pattern.

## Confirmed NOT candidates

- nixos-update-notifier, oomkiller, nix-hash — already Rust, wired via
  profiles/base.nix.
- homarr/invidious/*arr apps — third-party software.
- bin/fleet, bin/vm/*, bin/generations/*, bin/update/* wrappers — plumbing,
  excluded by user directive; scripts are fine there.
