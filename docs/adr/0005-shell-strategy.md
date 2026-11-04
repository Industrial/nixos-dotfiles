# ADR-0005: Nushell is the login shell; fish is a fallback with one writer

**Status:** Accepted
**Date:** 2026-11-04
**Mission:** `pln-mw2lhb7s-ch1ipd` (terminal frontier), leaf `leaf-shell-ownership`
**Relates to:** [ADR-0002](./0002-comin-pull-convergence.md) (comin pull-convergence) ·
[ADR-0003](./0003-kernel-hardening-single-source.md) clause 4 (`users.defaultUserShell` stays
unset)

## Context

Two things set `tom`'s login shell, and they disagreed.

```
bin/update/login-shell:7          sudo chsh -s /run/current-system/sw/bin/fish "tom"
features/cli/nushell/default.nix:19  users.users."${settings.username}".shell = pkgs.nushell;
```

`bin/update/system` called `bin/update/login-shell` on **every** run, immediately after
`nixos-rebuild switch`. So within one `bin/update/system` the imperative writer ran last and
won; but any activation that does not go through that script — a bare `nixos-rebuild switch`,
`bin/fleet`, or comin's pull-convergence from ADR-0002 — re-applied the declarative value and
flipped it back. Which shell a login got therefore depended on which tool had run most
recently. Live state at the time of writing:

```
$ getent passwd tom
tom:x:1000:100:tom:/home/tom:/run/current-system/sw/bin/nu
```

— the declarative writer happened to be last. `logs/update-login-shell` confirms the chsh did
run and did succeed at least once, so this was a live flip-flop, not dormant code.

A second defect was reported alongside it: that `features/cli/fish/default.nix:17` sources
`${havamalPlugin}/share/fish/vendor_conf.d/Hávamál.fish`, a path
`features/cli/fish/havamal.nix` never creates, making fish error on every interactive start.
**That does not reproduce.** `pkgs.fishPlugins.buildFishPlugin` overrides `buildPhase` but
keeps its own `installPhase`, which installs `conf.d/*.fish` from the source into
`$out/share/fish/vendor_conf.d/`, and upstream `Industrial/havamal-bash@v0.3.1` ships
`conf.d/Hávamál.fish`. The file exists, fish sources it, a stanza prints, and interactive
startup emits **zero bytes** on stderr. What is real is the *fragility*: the path
`default.nix` hardcodes was produced by an upstream convention rather than by this repo's own
`buildPhase`, so an upstream rename would have broken it at shell start rather than at build
time — exactly the failure that was reported, one upstream commit away.

### Measured startup cost

Mission measurement, drakkar, 2026-11-04, median of 5:

| shell | median |
|-------|--------|
| `nu -n` (no config) | 8 ms |
| `nu` (full repo config) | 15 ms |
| `nu -l` (login) | 25 ms |
| `fish -i` | 80 ms |

Re-measured during implementation on the same host and day, with two sibling agents building
concurrently, so the absolute numbers are inflated and only the shape is load-independent.
`hyperfine` is not installed yet (it arrives with the staples leaf), so this is
`date +%s%N` around 5 runs, median:

| probe | median | delta |
|-------|--------|-------|
| `fish --no-config` | 4 ms | binary floor |
| `fish` with `/etc/fish/config.fish`, non-interactive | 86 ms | **+82 ms** |
| `fish -i`, `/etc/fish` + repo `interactiveShellInit` | 206 ms | +120 ms |
| `nu -n -c exit` | 10 ms | |
| `nu -c exit` | 11 ms | +1 ms for the whole repo config |
| `nu -l -c exit` | 38 ms | +27 ms for login |

The `+82 ms` is **not** the repo's fish configuration — it is NixOS's own fish integration.
`/etc/fish/nixos-env-preinit.fish` does `fenv source …-set-environment`, a foreign-env
round-trip through bash on every fish start. The repo's `interactiveShellInit` pieces are
individually cheap above a 4 ms floor: Hávamál +3 ms, `direnv hook` +4 ms, `fzf --fish` +5 ms,
`fish_vi_key_bindings` +6 ms, `starship init` +9 ms. Removing the Hávamál greeting would buy
3 ms of a 206 ms startup, so there is no performance argument for dropping it.

The `nu -l` figure is the one worth acting on, and it is not this leaf's: the login path pays
for `features/cli/nushell/login.nu`'s own `bash --login -c "env -0"` round-trip, which a
separate leaf deletes.

### What `programs.fish.enable` still provides

Relevant for the obvious next question — "if fish is only a fallback, can it be a bare package?"
From nixpkgs `nixos/modules/programs/fish.nix`:

- `etc."fish/config.fish"` (:289) — the entry point that sources everything below
- `etc."fish/nixos-env-preinit.fish"` (:264) — puts the NixOS environment into a fish that was
  started from a non-NixOS-aware parent; this is what makes fish usable as a *rescue* shell
- `etc."fish/setEnvironment.fish"` (:249), `shellInit.fish` (:251), `loginShellInit.fish` (:252),
  `interactiveShellInit.fish` (:253) — babelfish translations of the NixOS environment
- `etc."fish/foreign-env/{shellInit,loginShellInit,interactiveShellInit}"` (:258-260) plus
  `pkgs.fishPlugins.foreign-env` (:62) — the fallback translator when babelfish is off
- `etc."fish/generated_completions"` (:353) — completions generated from `systemPackages`
- `environment.pathsToLink` for `/share/fish/vendor_conf.d`, `vendor_completions.d`,
  `vendor_functions.d` (:425-428) — without this, no fish plugin installed system-wide is found
- `environment.systemPackages = [ cfg.package ]` (:431)

A bare `pkgs.fish` in `systemPackages` gives none of it. A fallback shell that does not know
the system environment is not a fallback.

### fish is in `/etc/shells` from two independent sources

```
$ nix eval --json .#nixosConfigurations.drakkar.config.environment.shells
[ "…-nushell-0.116.1"               # features/cli/nushell/default.nix
, "…-fish-4.9.3"                    # features/cli/fish/default.nix:49-51
, "/run/current-system/sw/bin/fish"  # nixpkgs programs/fish.nix:434
, "…-fish-4.9.3/bin/fish"           # nixpkgs programs/fish.nix:435, lib.getExe
, "/run/current-system/sw/bin/bash", … ]
```

nixpkgs' `programs/fish.nix:433-437` sets `environment.shells` itself, and
`features/cli/fish/default.nix:49-51` sets it again. Consequence to remember: **disabling
`programs.fish.enable` would not remove fish from `/etc/shells`**, because this repo's own
`environment.shells` keeps it there. Anyone hoping to make fish unselectable by turning the
module off will be surprised. Conversely, removing the repo's `environment.shells` entry does
not remove it either, while the module is on.

### `users.defaultUserShell` is not the tool for this

ADR-0003 clause 4 decided `users.defaultUserShell` stays unset, falling through to the nixpkgs
default. It is a *fleet-wide* default for every user including system accounts; the per-user
`users.users.<name>.shell` this repo uses is a different option and is not constrained by that
clause. The fix for a login-shell disagreement is to have one writer of the per-user option —
never to reach for `defaultUserShell`.

## Decision

1. **`bin/update/login-shell` is deleted**, and its call site at `bin/update/system:43` is
   removed and replaced by a comment naming the single writer. The imperative writer is gone
   rather than rewritten to derive the shell from the NixOS config: a script that reads the
   declarative value and then writes it back through `chsh` is a no-op that can only ever
   disagree with activation during the window between the two.
2. **`users.users.<username>.shell` has exactly one writer**:
   `features/cli/nushell/default.nix:19`. Verified repo-wide — one match for
   `users.users.*.shell`, zero for `defaultUserShell`.
3. **`users.defaultUserShell` stays unset**, per ADR-0003 clause 4.
4. **Nushell is the login shell. fish is a fallback, and `programs.fish.enable` stays `true`**
   for the integration listed above. "Fallback" here means: not in `/etc/passwd`, still on
   `/etc/shells`, still configured well enough to be usable when nu cannot start.
5. **The Hávamál greeting stays, and `features/cli/fish/havamal.nix` now installs its
   `vendor_conf.d` entry explicitly** rather than relying on `buildFishPlugin`'s installPhase
   finding `conf.d/` upstream. An upstream rename now fails `nix build` instead of printing an
   error on every interactive fish start. The `source` line in `default.nix` is unchanged.
   Both halves are pinned by assertions (`features/cli/fish/havamal.assay.nix`
   `installsVendorConfEntry`, `features/cli/fish/default.assay.nix` `sourcesVendorConfEntry`),
   so the two files cannot drift apart silently.
6. **The reported "fish errors on every interactive start" is recorded as not reproducing**,
   with the evidence above, rather than being "fixed" by deleting a working feature. Removing
   the `source` line was the offered alternative; it would have removed behaviour on a false
   premise for 3 ms.

## Consequences

### Positive

- The login shell has one writer, so `nixos-rebuild switch`, `bin/fleet`, comin and
  `bin/update/system` all converge on the same value instead of racing.
- `bin/update/system` no longer needs `sudo` for a second, unrelated reason.
- `features/cli/fish/default.assay.nix` now fails if the fish module ever grows a `users`
  stanza — the single-writer property is asserted, not just currently true.
- The Hávamál path is a build-time dependency rather than a runtime hope.

### Negative

- Changing the login shell is now a `nixos-rebuild` away rather than a `chsh` away. That is
  the point, but it does mean the fast imperative escape hatch is gone. The escape hatch for a
  broken nu remains `chsh` by hand, or picking fish at the display manager.
- `features/cli/fish/havamal.nix` duplicates one file copy that `buildFishPlugin`'s
  installPhase would also do. The redundancy is deliberate and commented; a reader who does
  not read the comment will think it is dead work.
- The plugin derivation's output hash changes, so the next switch rebuilds it. It is a file
  copy.
- **Follow-up left undone:** `README.md:39` and `README.md:49` still advertise
  `bin/update/login-shell`. Those two lines are outside this leaf's file ownership and are
  stale as of this ADR.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Keep `bin/update/login-shell`, deriving the shell from `nixosConfigurations.<host>.config.users.users.<name>.shell` | Still a second writer. It would agree with activation almost always, which makes the rare disagreement harder to find, not rarer. |
| Make fish the login shell and demote nushell | Measured startup is 206 ms vs 11 ms, and the mission's direction is nu. |
| Drop `programs.fish.enable` for a bare `pkgs.fish` | Loses `/etc/fish/nixos-env-preinit.fish` and the `vendor_conf.d` link path — the two things that make fish work as a rescue shell. Also would not remove fish from `/etc/shells`, so it buys nothing it looks like it buys. |
| Remove the `source` line from fish's `interactiveShellInit` | The premise (broken path) is false, and the gain is 3 ms of 206 ms. Deleting a working feature under a bug-fix banner is the thing ADR-0004's alternatives table warns about. |
| Set `users.defaultUserShell = pkgs.nushell` | Forbidden by ADR-0003 clause 4, and wrong in substance: it would change the shell of every user, including system accounts. |

## Verification

All run on 2026-11-04, on drakkar, before the commit:

```bash
grep -rn 'users\.users\..*\.shell\|defaultUserShell' --include='*.nix' .   # 1 hit: features/cli/nushell/default.nix:19
nix build --impure --expr '(import <nixpkgs> {}).callPackage ./features/cli/fish/havamal.nix {}'
#   → $out/share/fish/vendor_conf.d/Hávamál.fish present, 106 bytes, content unchanged
#   → $out/share/fish/stanzas/ 164 files
fish -i < (echo exit)      # exit 0, 0 bytes on stderr — before and after this change
assay run .
bin/assay-coverage-check
bin/ci/deadnix
nix flake check --no-build --all-systems
```

## References

- `features/cli/nushell/default.nix:19` — the single writer
- `features/cli/fish/default.nix:17` — the `source` line, unchanged
- `features/cli/fish/havamal.nix` — explicit `vendor_conf.d` install
- nixpkgs `nixos/modules/programs/fish.nix` — `/etc/fish` generation, `pathsToLink`, `shells`
- nixpkgs `pkgs/shells/fish/plugins/build-fish-plugin.nix` — the `installPhase` that was
  silently supplying the `vendor_conf.d` entry
