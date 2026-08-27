# FlexGet on native services.flexget — crypto dep, Web UI bundle, lock races

Session 2026-08-25 (mimir rollout; commits a5052cc7, b88602d6, b550a946, a7a4c45c, ac86b1c1, 59dfca54).

## Missing cryptography dependency
nixpkgs' flexget dependency list omits `cryptography`, but upstream's
utils/waf module imports it unconditionally during daemon startup ->
ModuleNotFoundError before anything serves. Fix in the feature module:

```nix
flexgetFixed = pkgs.flexget.overridePythonAttrs (old: {
  dependencies = (old.dependencies or []) ++ [pkgs.python3Packages.cryptography];
});
```

Verify the import against the built env's interpreter before shipping
(`$(dirname interp)` trick: read the shebang/env PATH of bin/flexget).

## Web UI stub vs prebuilt bundle
nixpkgs builds flexget from the GitHub source tarball where
`flexget/ui/v2/dist` is only a stub page ("run the WebUI build steps").
The PyPI wheel ships the full prebuilt bundle. Recipe:

1. `fetchurl` the exact wheel (hash via `nix hash file`), stdenv
   derivation that unzips only `flexget/ui/v2/*` into `$out/share/webui`.
2. Splice it over the stub in the package override:

```
postInstall = (old.postInstall or "") + ''
  rm -rf "$out/${py.sitePackages}/flexget/ui/v2"
  cp -r "${webui}/share/webui" "$out/${py.sitePackages}/flexget/ui/v2"
'';
```

Note: flexget's passthru has NO `pythonModule`; use `pkgs.python3.sitePackages`.
Verify by curling :5050 (must NOT contain "Failed to load Flexget Web UI")
and fetching one `/ui/v2/dist/assets/*.js` with 200.

## Lock-file races (three layers)
Stale `.flexget-lock` -> CRITICAL manager "Another process (PID ...) is
running", exit 1.

1. Per-start heal: root-prefixed ExecStartPre `rm -f <home>/.flexget-lock`.
2. The module's ExecStop runs `flexget daemon stop`, spawning a SECOND
   Python process that touches the lock while systemd restarts the unit,
   racing the new daemon's boot. Kill it: `ExecStop = lib.mkForce "";`
   (SIGTERM alone stops the daemon cleanly).
3. An old generation mid-crash-loop (Restart=always) auto-restarts THROUGH
   switch-to-configuration and can recreate the lock before the new unit
   starts. Quiesce in an activation script (runs as root on every
   activation):

```nix
system.activationScripts.flexgetQuiesce.text = ''
  ${pkgs.systemd}/bin/systemctl stop flexget.service 2>/dev/null || true
  ${pkgs.coreutils}/bin/rm -f ${dir}/.flexget-lock
'';
```

Signature of losing the race: deploy exits 1 with "Revoking previous
deploys", journal shows the NEW daemon dying on the lock seconds into the
switch, generation rolls back to the broken one.

## Debugging path that worked
- deploy-rs stderr carries `warning: the following units failed: X.service`
  and the `starting the following units:` line — read the LOG, don't guess
  from the generic "rolled back" banner.
- Bound the journalctl window around the switch timestamp
  (`--since/--until`) to separate the new unit's first failure from the
  old unit's repeating loop noise.
- `systemctl show <unit> -p ExecStart -p ActiveState -p NRestarts` confirms
  which generation is actually live.
- Prefer encoding remediation (stops, rm, mkdir) in activation scripts /
  unit pre-steps over ad-hoc remote `sudo`: it survives rollbacks, is
  reviewable, and re-applies on every future switch.
