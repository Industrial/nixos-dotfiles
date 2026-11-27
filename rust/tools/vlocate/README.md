# vlocate

Where a command comes from (GH-245). It **complements** nix-index, which answers from the
community's prebuilt nixpkgs-wide database and stays as it is. vlocate adds two things:

- **the fleet's own systems**, read from the store database: this host's
  `/run/current-system`, and on the cache host every fleet host's latest main build
  (vci's roots, `/var/lib/vci/roots/main-<host>`);
- **a command-not-found hint** for nushell (the login shell, which nix-index has no hook
  for), fish and zsh, which also asks nix-locate's database about nixpkgs.

Written in Voltaic 0.3.0 (`src/*.vlt`, compiled by `build.rs`) with id_effect 0.13.0, on
nix-store-core's read-only store database.

```
vlocate [bin] NAME [--json]      where NAME comes from; exit 1 when nowhere, 2 when nowhere
                                 and nix-locate failed (nixpkgs unknown, see nixpkgs_error)
vlocate hint NAME                the shells' hint on stdout; exit 1 when there is none (nushell)
vlocate not-found NAME           the hint on stderr, always exit 127 (fish, zsh)
options: [--current PATH] [--roots DIR] [--db FILE] [--nix-locate PROG | --no-nixpkgs]
```

```
$ cowsay
cowsay: command not found.
  In the fleet's systems:
    cowsay-3.8.4  (this host, mimir)  /nix/store/…-cowsay-3.8.4/bin/cowsay
  In nixpkgs: nixpkgs#cowsay, nixpkgs#neo-cowsay
  Try it once: , cowsay
```

## One lookup

1. **Systems:** this host, then each `main-<host>` root where vci runs, by host name.
2. **Closures:** each system's closure from `/nix/var/nix/db/db.sqlite`, opened read-only,
   one after another. A system that can't be read is skipped with a note.
3. **Paths:** which paths of their union have `bin/<name>`, as a file or a link.
4. **nixpkgs:** `nix-locate --minimal --whole-name --at-root /bin/<name>`, the prebuilt
   database features/cli/nix-index installs. nix-index 0.1.11 has no `--top-level` (top-level
   only is its default), and passing it was a silent miss until GH-442. With no nix-locate
   this half is empty, never an error. A nix-locate that runs and fails is an error, not "no
   hits": `--json` carries it as `nixpkgs_error` (null otherwise), `bin` notes it on stderr,
   and the hint keeps the fleet's part with "In nixpkgs: not searched". Each lookup pays for
   the nix-locate call: about 1.1 s on drakkar, 6 s on muninn under load (2026-11-27).

A name that a shell could not have meant is refused without a lookup: empty, `.`, `..`, a
slash, or whitespace. Measured in the VM test at 0.11 s per lookup, `su` included.

## The shells

- **nushell:** `features/cli/vlocate/vlocate.nu`, generated into the vendor autoload
  through `cli.shellInit.extraAutoload` (and nu-checked at build), sets
  `$env.config.hooks.command_not_found`. Its value is the hint, or null.
- **fish:** `fish_command_not_found` runs `vlocate not-found`.
- **zsh:** `command_not_found_handler` runs it, only where `programs.zsh` is on.
- nix-index's own fish and zsh hooks are turned off (`mkForce false`), so a missing command
  gets one hint. bash keeps nix-index's hook.

Rollback: `features.cli.vlocate.enable = lib.mkForce false;` removes the hooks and gives
fish and zsh nix-index's back.
