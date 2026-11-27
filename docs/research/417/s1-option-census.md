# #417 S1: NixOS option census for the fleet

Stage S1 of Industrial/nixos-dotfiles#417 (reimplement NixOS on Voltaic + id_effect). This
census lists which NixOS options each fleet host sets or depends on, so the Voltaic module
system can be sized.

- Measured 2026-11-27 on drakkar at repo `87be3c29` (origin/main plus this directory only) and
  nixpkgs `619c39f` (26.11.20261122).
- Raw and summarised data: [`s1-options.json`](s1-options.json).
- Rerun: [`run-census.sh`](run-census.sh), then [`census.nix`](census.nix), then
  [`summarise.sh`](summarise.sh).

## Method

- `census.nix` loads the repo flake with `builtins.getFlake "git+file://…"` (never `path:`). It
  walks `nixosConfigurations.<host>.options` down to every option (17,830 per host) and keeps
  each option whose winning priority (`highestPrio`) is below `mkOptionDefault` (1500) and that
  `isDefined`. So "defined" means some module set the option beyond its declared default.
  Definitions under a false `mkIf` drop out, so this is the set of definitions that actually take
  effect.
  - The priority check runs before `isDefined`. On an unset option, `isDefined` forces the
    option's default, and some upstream defaults fail to evaluate when unset (lanzaboote's
    `publicKeyFile`).
  - Two options throw on every host and are listed as `unevaluable`:
    `services.geoclue2.staticLatitude` and `staticLongitude`.
- Each winning definition's file in `definitionsWithLocations` is classified by store prefix as
  `repo:`, `nixpkgs:` or `<flake-input>:`. Only file names are read, never values.
- Every option then gets one class:
  - **ours**: the option is declared in this repo (`features.*`, `profiles.*`,
    `security.stig.*`, `vfiles.*`, `cli.*`).
  - **repo**: an upstream option that the repo sets.
  - **input**: no repo definition, but a non-nixpkgs flake input sets it (stylix, nixvim,
    nix-index-database, disko, comin, lanzaboote).
  - **nixpkgs**: only nixpkgs modules set it. This is upstream wiring that the toplevel depends
    on without the repo touching it.
- **Active upstream modules** are the non-repo files that contribute a winning definition.
  Bookkeeping options are left out (`assertions`, `warnings`, `meta.*`, `documentation.*`),
  because every imported module defines them unconditionally.
- **Subtree ownership.** For the attrsOf subtrees that S3 targets (`systemd.services`,
  `users.users`, `users.groups`, `environment.etc` and others), every final entry is attributed
  to the sources whose definitions name it.
- **Timing.** `/run/current-system/sw/bin/time -v` wraps
  `nix eval --no-eval-cache --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.
  That instantiates the `.drv` files but builds nothing. The hosts ran one at a time.
- **Limits.**
  - Only top-level options are counted. Sub-options inside submodules
    (`systemd.services.<n>.serviceConfig`, for example) are not counted separately; the subtree
    ownership tables size those instead.
  - "Depends on" is approximated by the *nixpkgs* class and the active-module list. An exact
    read-set (which option values the toplevel derivation actually forces) would need an
    evaluator trace. S1 did not do this.

## Per host

| host | options walked | defined | ours | repo | input | nixpkgs-only | active upstream modules |
|---|---|---|---|---|---|---|---|
| drakkar | 17,830 | 660 | 194 | 173 | 13 | 280 | 246 |
| mimir | 17,830 | 721 | 242 | 189 | 14 | 276 | 248 |
| huginn | 17,830 | 619 | 162 | 161 | 15 | 281 | 245 |
| muninn | 17,830 | 743 | 264 | 186 | 15 | 278 | 248 |
| **union** | 17,830 | **799** | **294** | **216** | **14** | **275** | **256** |

599 of the 799 options are defined on all four hosts. Upstream options (repo + input +
nixpkgs-only) number 505 across the union. Only 230 of those are touched by our own config or
by flake inputs (216 + 14).

### Defined options by top-level namespace

Columns: one per host, then the union split by class.

| namespace | drakkar | mimir | huginn | muninn | union | ours | repo | input | nixpkgs |
|---|---|---|---|---|---|---|---|---|---|
| `features` | 180 | 225 | 151 | 245 | 273 | 273 | 0 | 0 | 0 |
| `services` | 132 | 152 | 133 | 148 | 162 | 0 | 66 | 1 | 95 |
| `programs` | 55 | 44 | 49 | 49 | 55 | 1 | 25 | 4 | 25 |
| `boot` | 48 | 48 | 49 | 48 | 49 | 0 | 15 | 1 | 33 |
| `security` | 24 | 36 | 24 | 37 | 37 | 8 | 19 | 0 | 10 |
| `systemd` | 36 | 36 | 36 | 36 | 36 | 0 | 12 | 0 | 24 |
| `system` | 31 | 29 | 29 | 29 | 31 | 0 | 4 | 1 | 26 |
| `networking` | 23 | 23 | 23 | 23 | 23 | 0 | 9 | 0 | 14 |
| `hardware` | 20 | 19 | 17 | 19 | 20 | 0 | 12 | 0 | 8 |
| `environment` | 18 | 18 | 18 | 18 | 18 | 0 | 6 | 0 | 12 |
| `stylix` | 17 | 17 | 17 | 17 | 17 | 0 | 12 | 5 | 0 |
| `nix` | 7 | 9 | 7 | 7 | 9 | 0 | 6 | 0 | 3 |
| `fonts` | 8 | 8 | 8 | 8 | 8 | 0 | 6 | 0 | 2 |
| `profiles` | 8 | 6 | 6 | 7 | 8 | 8 | 0 | 0 | 0 |
| `xdg` | 8 | 7 | 8 | 8 | 8 | 0 | 3 | 0 | 5 |
| `virtualisation` | 6 | 6 | 6 | 6 | 6 | 0 | 5 | 0 | 1 |
| `i18n` | 5 | 5 | 5 | 5 | 5 | 0 | 2 | 0 | 3 |
| `nixpkgs` | 5 | 5 | 5 | 5 | 5 | 0 | 3 | 0 | 2 |
| `documentation` | 4 | 4 | 4 | 4 | 4 | 0 | 0 | 0 | 4 |
| `meta` | 4 | 4 | 4 | 4 | 4 | 0 | 0 | 0 | 4 |
| `users` | 3 | 3 | 3 | 3 | 3 | 0 | 2 | 0 | 1 |
| `vfiles` | 3 | 2 | 2 | 2 | 3 | 3 | 0 | 0 | 0 |
| `zramSwap` | 3 | 3 | 3 | 3 | 3 | 0 | 3 | 0 | 0 |
| `ids` | 2 | 2 | 2 | 2 | 2 | 0 | 0 | 0 | 2 |
| `powerManagement` | 2 | 2 | 2 | 2 | 2 | 0 | 2 | 0 | 0 |
| others (`assertions`, `warnings`, `cli`, `disko`, `fileSystems`, `image`, `lib`, `swapDevices`) | 1 each | | | | 8 | 1 | 4 | 2 | 1 |

`systemd`, `users` and `environment` look small here because `systemd.services`,
`users.users` and `environment.etc` are each a single attrsOf option. Their size is in the
subtree tables below.

### 30 biggest upstream namespaces (union, two levels, our own options excluded)

| namespace | defined | repo | input | nixpkgs-only |
|---|---|---|---|---|
| `boot.initrd` | 27 | 4 | 1 | 22 |
| `environment` | 18 | 6 | 0 | 12 |
| `services.gnome` | 18 | 5 | 0 | 13 |
| `services.xserver` | 16 | 2 | 0 | 14 |
| `systemd` | 16 | 4 | 0 | 12 |
| `system` | 15 | 2 | 1 | 12 |
| `services.displayManager` | 12 | 3 | 0 | 9 |
| `boot` | 8 | 5 | 0 | 3 |
| `boot.loader` | 8 | 3 | 0 | 5 |
| `stylix.fonts` | 8 | 8 | 0 | 0 |
| `system.nssDatabases` | 8 | 0 | 0 | 8 |
| `networking.firewall` | 7 | 5 | 0 | 2 |
| `services.homepage-dashboard` | 7 | 7 | 0 | 0 |
| `stylix` | 7 | 4 | 3 | 0 |
| `fonts.fontconfig` | 6 | 5 | 0 | 1 |
| `networking` | 6 | 1 | 0 | 5 |
| `nix` | 6 | 3 | 0 | 3 |
| `programs.bash` | 6 | 0 | 0 | 6 |
| `security.sudo` | 6 | 5 | 0 | 1 |
| `services.pipewire` | 6 | 6 | 0 | 0 |
| `systemd.user` | 6 | 2 | 0 | 4 |
| `hardware.graphics` | 5 | 3 | 0 | 2 |
| `services.comin` | 5 | 4 | 1 | 0 |
| `services.firezone` | 5 | 0 | 0 | 5 |
| `services.openssh` | 5 | 2 | 0 | 3 |
| `services.prometheus` | 5 | 5 | 0 | 0 |
| `services.rustdesk-server` | 5 | 5 | 0 | 0 |
| `virtualisation.docker` | 5 | 5 | 0 | 0 |
| `hardware` | 4 | 2 | 0 | 2 |
| `meta` | 4 | 0 | 0 | 4 |

The namespaces are flat. No upstream namespace has more than 27 defined options, and the tail
is long: 162 `services.*` options are spread over about 60 services.

## Subtrees S3 would own (entries per host, attributed by source)

| subtree | drakkar | mimir | huginn | muninn | union: repo / mixed / nixpkgs (+input) |
|---|---|---|---|---|---|
| `systemd.services` | 114 | 109 | 101 | 98 | 19 / 6 / 98 (+1 comin) |
| `systemd.user.services` | 19 | 16 | 17 | 19 | 6 / 2 / 11 |
| `systemd.sockets` | 10 | 9 | 9 | 9 | mostly nixpkgs |
| `systemd.timers` | 6 | 6 | 5 | 5 | 0 / 3 / 3 |
| all systemd units | 146 | 146 | 130 | 126 | |
| `systemd.tmpfiles.rules` (rules repo/nixpkgs) | 9/26 | 16/24 | 4/24 | 10/24 | |
| `users.users` | 65 | 68 | 65 | 67 | 5 / 1 / 64 |
| `users.groups` | 57 | 60 | 56 | 58 | 8 / 0 / 54 |
| `environment.etc` (enabled) | 177 | 190 | 175 | 190 | 20 / 1 / 177 |
| `system.activationScripts` | 17 | 31 | 32 | 32 | |
| `environment.systemPackages` (items repo/nixpkgs) | 292/278 | 230/275 | 257/276 | 269/277 | |

On drakkar and mimir, the repo-authored systemd services are mostly our own v* tools: vdeploy,
vgc, vgc-check, vopt, vhealth, vexporter, vcache, vci, vfiles, vfetch-serve, vgen-prune, vverify
and vdaemon-proxy. The rest are oomkiller, nix-daemon-listen, lock-root-password and
rfkill-block-wlan. The mixed services are units the repo patches on top of a nixpkgs unit:
dbus-broker, display-manager, tailscaled, searx, nfs-server and audit-rules-nixos.

## Upstream modules we depend on

- **Active upstream modules:** 256 across the union (245–248 per host). These files contribute
  winning definitions, and the toplevel is built from them. The heaviest, by winning definitions
  across the union, are:
  - desktop: `services/desktop-managers/gnome.nix` (56), `display-managers/gdm.nix` (21)
  - `system/boot/systemd.nix` (26)
  - `services/networking/networkmanager.nix` (21)
  - `services/system/dbus.nix` (19)
  - `ssh/sshd.nix` (14)
  - `avahi-daemon.nix`, `boot/kernel.nix`, `systemd/initrd.nix` (13 each)
  - `pipewire.nix`, `hardware/udev.nix` (12 each)
  - `users-groups.nix`, `wayland/hyprland.nix`, `security/polkit.nix`, `tasks/filesystems.nix`
    (11 each)
  - `pam.nix`, `netbird.nix`, `xserver.nix`, `luksroot.nix`, `systemd/user.nix`,
    `network-interfaces.nix` (10 each)

  The full list with counts is under `contributors` in the JSON.
- **Upstream modules our config drives directly:** 105. These modules declare the 230 options
  that the repo or a flake input sets (`upstreamDriven` in the JSON). The top ones:
  - stylix `fonts.nix` (8)
  - `homepage-dashboard` (7)
  - 5 each: `fontconfig`, `sudo`, `pipewire`, `rustdesk-server`, `firewall`, `systemd.nix`
  - 4 each: comin options, `hyprland`, `pam`, `gnome`, `grafana`, `prometheus`, `kernel`,
    `oomd`, `docker-rootless`
  - Most of the rest have 1–3 options each.
- **Non-nixpkgs inputs in the evaluation:** stylix, nixvim, nix-index-database, disko, comin
  and lanzaboote.

## Evaluation baseline (the number Voltaic must beat)

`toplevel.drvPath`, `--no-eval-cache`, one host at a time, on drakkar (32 threads, 61 GB):

| host | wall | user | sys | peak RSS |
|---|---|---|---|---|
| drakkar | 23.97 s | 24.54 s | 2.80 s | 2,627 MB |
| mimir | 21.69 s | 23.37 s | 2.45 s | 2,523 MB |
| huginn | 20.71 s | 22.91 s | 2.29 s | 2,656 MB |
| muninn | 23.87 s | 25.04 s | 2.65 s | 2,707 MB |

- A run with `NIX_SHOW_STATS` on drakkar recorded:
  - 47.7 M thunks
  - 78.8 M values
  - 25.3 M function calls
  - a 2.26 GB GC heap
- The census eval costs about the same (20–24 s, 2.5–2.7 GB; mimir measured 37.8 s wall but only
  28 s user, so it was contended). Forcing every option's priority costs about as much as
  building the toplevel.
- Baseline per host: **about 22 s and about 2.6 GB**, or about 90 s for the fleet run
  sequentially. Running the four in parallel would need about 10.5 GB, which is why hosts
  currently evaluate one at a time on this box.

## Sizing conclusion for S3

1. **The module system is small; the module library is not.**
   - Our own declared surface is 294 options: 273 `features.*` toggles, 8 `profiles.*`, 8
     `security.stig.*`, plus `vfiles` and `cli`. Almost all are boolean `enable` flags. A typed
     Voltaic record covers them, and S2 (typed `features/catalog.nix`) absorbs most of it.
   - The upstream options we set directly number 230, spread over 105 modules, most with 1–5
     options each.
   - The toplevel, however, is assembled by **256 active upstream modules**, which wire 275
     options among themselves without us. A full take-over (S5) means reproducing that
     behaviour. Owning a subtree only means owning our slice of it.
2. **Own the repo-authored slice first and leave upstream entries to NixOS.**
   - Voltaic generates the entries the repo writes, and they are imported as ordinary NixOS
     definitions.
   - The oracle gate compares the merged subtree.
   - Per subtree, the repo slice is small: about 25 of 124 system services, 6 of 70 users, 8 of
     62 groups, and 21 of 198 `/etc` entries (union).
3. **Order:**
   1. **users/groups.** Smallest, flat and static: 5 users, 8 groups, 1 mixed entry. They are
      the easiest to oracle: `users-groups.json` plus `/etc/passwd`/`group`. They also force
      the uid/gid allocation types (`ids.*`) early.
   2. **systemd units.** About 25 repo services, plus timers and user services, mostly our own
      v* tools. Six mixed units (dbus-broker, display-manager, tailscaled, searx, nfs-server,
      audit-rules-nixos) are where Voltaic must express NixOS merge semantics: a definition
      layered on an upstream unit at a priority. That makes them the right test bed for the
      typed merge/priority design.
   3. **`/etc` last.** The repo authors only 21 of the 177–190 entries per host. The other
      160–177 entries are generated by nixpkgs modules: pam, sshd, dbus, nsswitch, fonts and
      others. `/etc` is the sink for every upstream module, so owning it outright implies
      owning most of the 256 modules. Take the repo slice in S3 and leave the whole `/etc` to
      S5.
4. **What S4/S5 will cost.**
   - The heavy upstream dependencies are the desktop stack (gnome, gdm, xserver,
     displayManager, pipewire), the systemd core and initrd, networkmanager, dbus, udev, pam,
     sshd, and users-groups. Together they account for most of the 275 nixpkgs-only wiring
     options.
   - huginn and muninn (the test hosts) carry the same desktop modules as drakkar. The active
     module count barely changes across hosts (245–248).
   - So S4 on a test host is not much smaller than the whole fleet. Plan an escape hatch:
     consume upstream NixOS module output (unit files and /etc fragments) as opaque, pinned
     inputs, the way packages come from the package index. Keep that hatch for the desktop
     stack until the core is oracle-equal.
5. **Performance target:** below about 22 s and about 2.6 GB per host. With ~800 defined options
   and ~150 units per host, a native evaluator has a lot of headroom. The 47.7 M thunks are
   overhead of the lazy module fixpoint, not real work.
