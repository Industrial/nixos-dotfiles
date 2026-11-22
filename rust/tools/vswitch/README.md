# vswitch

The local rebuild (GH-241). It replaces `nixos-rebuild` and `nh`, and it is put together
from the Layer A pieces rather than written a third time: the build goes through **vmon**,
the diff is **vdiff**'s, and the switch is **vdeploy**'s apply transaction, linked as a
library, with its **vhealth** check and rollback. vdeploy itself is unchanged. vswitch is
written in Voltaic 0.3.0 (`src/*.vlt`, compiled by `build.rs`) with id_effect 0.13.0.

```
vswitch switch|boot|test|build|dry [--flake DIR] [--host NAME] [--toplevel PATH]
        [--out-link PATH] [--ask] [--health-window DURATION] [--health-as USER]
        [--state-dir DIR] [--db FILE] [TOOLS]
TOOLS:  [--nix PROG] [--vmon PROG | --no-vmon] [--systemd-run PROG] [--systemctl PROG]
        [--nix-env PROG] [--nix-store PROG] [--setpriv PROG] [--elevate PROG]
```

| verb | does |
|---|---|
| `switch` | build, diff, then vdeploy's apply: `switch-to-configuration test`, vhealth on the new generation's own probes, then the boot default (`nix-env --set` + `switch-to-configuration boot`), or a rollback to the previous generation, which is marked bad |
| `boot` | build, diff, make it the boot default; nothing is activated |
| `test` | build, diff, activate it; the boot default is not touched |
| `build` | build (`./result`) and diff; needs no root |
| `dry` | `nix build --dry-run`: what would be built and fetched |

`--flake` defaults to `.`, `--host` to this machine's hostname, so `vswitch switch` in
`~/.dotfiles` is `nixos-rebuild switch --flake .#$(hostname)`. `--toplevel` skips the build
and uses a toplevel that already exists (a specialisation, a `result`, an old generation).

## One run

1. **Build**, as the calling user: `nix build --out-link LINK <flake>#nixosConfigurations."<host>".config.system.build.toplevel`,
   through `vmon --` when there is one. The link is the GC root while the switch runs: in
   `$XDG_RUNTIME_DIR/vswitch/result`, never in a shared `/tmp` (whoever owns the link's
   directory chooses what is activated).
2. **Diff**: vdiff's report of `/run/current-system` against the new toplevel, printed.
3. **Decide** (`plan.vlt`, pure): a switch to the generation that already runs does nothing
   (or only `boot`, when the boot default moved); `test` and `boot` likewise. Nothing to do
   means no root is asked for.
4. `--ask`: confirm.
5. **Activate**, elevated (`sudo`, unless already root) in a transient unit:

   ```
   sudo systemd-run --unit=vdeploy-apply --service-type=exec --collect --wait --pipe --quiet \
     vswitch apply --toplevel X --state-dir /var/lib/vdeploy --health-window … [--health-as vhealth …]
   ```

   `vswitch apply` is vdeploy's transaction, with vdeploy's own option parser
   (`vdeploy::app::program`); `vswitch activate boot|test X` is the same `LiveSystem`'s
   `nix-env --set` and `switch-to-configuration`.

Exit 0 when the host ends where it was asked to be; 1 on a usage error, a failed build, or
an activation that was rolled back, refused or failed; 130 on Ctrl-C.

## Why vdeploy's unit and ledger

- **One switch at a time.** The unit name is vdeploy's (`vdeploy-apply`). systemd refuses a
  second unit of one name, and vdeploy's daemon waits while one runs, so a local switch and
  the deploy agent never switch at once.
- **A switch must survive its own activation.** A switch can restart the session or the
  unit it was started from; in its own unit it finishes regardless (the same reason
  vdeploy has the unit, and nixos-rebuild-ng runs switch-to-configuration under systemd-run).
- **One ledger.** `/var/lib/vdeploy` holds the bad marks, `inflight.json`, `last.json` and
  `deploys.jsonl`. A generation that failed its health check under vswitch is refused by
  vdeploy too, and the other way round; an interrupted local switch is resumed by the next
  apply, whoever starts it.

On a host where vdeploy deploys, the next commit on main is still switched to by vdeploy:
vswitch is for experiments and console recovery, not a second deployer.

## Tools

The activation runs under sudo (which resets PATH) and inside a transient unit (with
systemd's PATH), so every program is passed as an absolute path. Bare names are resolved
on the caller's PATH first. The NixOS feature (`features/cli/vswitch`) installs a wrapper
that passes this host's paths, `--vmon` when cli-core has vmon, and `--health-as vhealth`
when the host runs vhealth (restricted Nix daemons refuse `nobody`).

## Take-over and rollback

`profiles/cli-core.nix` enables `features.cli.vswitch`, and `bin/update/system` switches
through it. nh stays installed off the default path (nothing calls it), so the rollback has
a working tool at once. The rollback is one option: `features.cli.vswitch.enable =
lib.mkForce false;` sends `bin/update/system` back to `nixos-rebuild` (asserted in
`profiles/cli-core.assay.nix` and `bin/dev.d/test.sh`).

## Bad marks and the shared unit

- Only `switch` runs vdeploy's apply, so only `switch` can mark a generation bad. `test`
  and `boot` never write the ledger. A mark names a **store path** (that exact
  generation), not a commit. vdeploy refusing it later is intended: the same closure
  failed the same host's health check. A commit whose generation differs is unaffected,
  and switching to the marked generation by other means clears the mark (vdeploy's own
  rule for the running generation).
- When `vdeploy-apply.service` is already running (vdeploy, or another vswitch), vswitch
  stops before elevating, says so, and touches nothing: no activation, no mark, no
  rollback of the other's switch. A start that races past that check is refused by
  systemd itself, because a unit of that name already exists.

## Tests

- `src/*.vlt` (cargo test, also the package's checkPhase): the command lines (vmon, dry run,
  elevation, the unit), that what the unit is handed parses back through vdeploy's own
  apply parser, which activation each verb needs, and the whole run against a scripted
  world: a failed build or a "no" to `--ask` activates nothing, build and dry never
  activate, the running generation is not switched to again.
- `features/cli/vswitch/test.nix` (`nix build .#checks.x86_64-linux.vswitch-vm`): a
  drakkar-like VM (restricted daemon, vhealth), switched by a non-root user: a forced-failing
  health check rolls back and marks the generation bad, the bad generation is refused, a
  healthy switch is kept, `test` and `boot` move only what they should, and the daemon and
  the web page are checked as that user after every step.
