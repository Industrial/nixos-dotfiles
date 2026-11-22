# /etc: setup-etc.pl against `system.etc.overlay` on drakkar (GH-185)

First a measurement, then a feature: `features.nixos.etc-overlay`, off by default and
enabled on no host, which carries the stateful files across a live switch both ways and
across the first boot both ways. See "The feature" at the end. Turning it on for a host
is the user's decision.

## The test

`features/nixos/etc-overlay/test.nix` (the measurement) and `test-live-switch.nix` (the
feature's gate), both on `node.nix`, with the colocated suite `test.assay.nix`:

    nix build .#checks.x86_64-linux.etc-overlay-stock         # setup-etc.pl
    nix build .#checks.x86_64-linux.etc-overlay-on            # system.etc.overlay, mutable
    nix build .#checks.x86_64-linux.etc-overlay-live-switch   # the feature: in and out, live and cold

Each check evaluates drakkar twice: the node and one specialisation (or, for the gate,
one `extendModules` extension). All of them share
drakkar's own package set. That keeps each check inside flake-checks' 8 GiB eval budget,
at about 7.2 GiB peak under nix-eval-jobs.

CI does not build VM tests on PRs. Run them locally through the serialized VM wrapper.

The node is drakkar's own `hosts/drakkar/configuration.nix`, with every profile and host
feature (userborn included). It differs from the host in three ways:
- `disko.nix` is disabled, because its LUKS/btrfs layout cannot exist in a VM.
- `services.timesyncd.enable` and `DefaultTimeoutStartSec` are forced, because they
  conflict with qemu-vm.
- `stock` and `on` add an `alt` specialisation, one /etc file apart, to switch between.
  `live-switch` extends the node with the feature on instead.

A wrapper around the `etc` activation snippet logs `gh185-etc-step ns=<n>` to the journal.

## Numbers

These are from main at 3131c7f9, VM with 4 vCPU and 6 GiB, 10 switches per variant.

| | setup-etc.pl | overlay (mutable) |
|---|---|---|
| `/etc` step per switch, median (min to max) | 173.4 ms (115 to 245) | 147.1 ms (129 to 243) |
| the same, second run (final test layout) | 152.5 ms (108 to 206) | 152.2 ms (118 to 179) |
| whole `switch-to-configuration test`, median | 5.09 s; second run 5.13 s | 4.88 s; second run 4.58 s |
| `/etc` step at boot | 167 ms in `initrd-nixos-activation` | 2.5 ms (skipped); the initrd mounts the erofs metadata image (~34 ms) and runs `rw-etc` (~31 ms) |
| boot (systemd-analyze) | 11.1 s | 10.8 s |

An earlier run at fd9eb137 on a busier host gave 197.5 ms against 129.7 ms per step,
and 7.85 s against 3.43 s per switch. That wall-time gap was host noise; it did not
come from /etc.

Every switch in both variants returned rc=4, and in both the only failed unit is
`vcache.service`, which has no tailnet in a VM.

Reading: setup-etc.pl is not a bottleneck at drakkar's size (174 `environment.etc`
entries). The overlay saves at most a few tens of milliseconds per switch (none at all
in the second run), so a Rust rewrite of setup-etc.pl would buy no more.

## Who writes /etc at runtime

The overlay's upperdir (`/.rw-etc/upper`), after boot, switches, `chpasswd` and
`nmcli connection add`:
- `passwd`, `group`, `shadow`, `subuid`, `subgid` (and the `-` backups), `.pwd.lock`
- `machine-id`
- `ssh/ssh_host_{ed25519,rsa,mldsa44_ed25519}_key{,.pub}`
- `NetworkManager/system-connections/*`
- `resolv.conf`
- `.updated`
- directories `credstore`, `credstore.encrypted`, `colord`, `gnome-remote-desktop`,
  `avahi/services`, `nixos`

The stock variant shows the same set as non-symlink files that `/etc/.clean` does not
own. A read-only listing of the live drakkar /etc adds `adjtime`,
`mullvad-vpn/{account-history,device,settings}.json`, `wpa_supplicant/imperative.conf`,
`security/opasswd`, `resolv.conf.bak` and `NIXOS`. `NetworkManager/system-connections`
(mode 700) needs root to list:

    sudo ls -la /etc/NetworkManager/system-connections

None of these is a declared `environment.etc` path, so no upper copy shadows a managed
file. The immutable overlay (`mutable = false`) is not an option here: NM, sshd,
resolvconf and mullvad all write to /etc, and `mutableUsers` is still on.

## Hazards

**A live switch from setup-etc.pl to the overlay loses state.** The overlay is mounted
over the old /etc and hides it. Nothing is deleted, but nothing is migrated either. The
first `live-switch` check (PR #236, the bare upstream option, before the feature)
booted setup-etc.pl and switched into an `overlay` specialisation, with these results:
- `machine-id` is absent afterwards.
- The NM connection is absent.
- `tom` has no entry in `/etc/shadow`.
- The ssh host key is regenerated with a new fingerprint.
- polkit and mandb fail with `217/USER`, because the user database was written into
  the old /etc before the remount hid it.

**A reboot into the overlay without a copy starts /etc from scratch.** The passwords
and host keys set on the old /etc are lost, machine-id is new, and the NM/VPN profiles
and the mullvad device identity are gone. tom's password would fall back to
`initialHashedPassword`, the hash of `test`.

So the bare upstream option cannot be adopted on an existing host. The state has to be
copied into `/.rw-etc/upper` before the overlay first mounts, on a live switch as well
as on the first boot, and back out on the way back. That is what the feature below does.

## The feature

`features.nixos.etc-overlay` (`features/nixos/etc-overlay/`): `system.etc.overlay` with
`mutable = true`, plus the carry-over that upstream lacks. Off by default, enabled on no
host.

**When upstream mounts the overlay.** On a live `switch-to-configuration`, upstream's `etc`
activation snippet (`nixos/modules/system/etc/etc.nix`, ordered after `users`, `groups`
and `specialfs`) mounts the erofs metadata image and, if /etc is not yet a mountpoint,
mounts the overlay straight over it. At boot, the initrd does it instead:
`initrd-find-etc`, then the metadata mount, `rw-etc.service`, and `sysroot-etc.mount`.

**Carry-in, before each of those:**
- *Live:* an activation snippet ordered before `etc`, when /etc is not a mountpoint.
- *Cold:* an initrd unit after the metadata mount, before `rw-etc.service` and
  `sysroot-etc.mount`.

Either one copies every stateful file of the plain /etc into `/.rw-etc/upper`, only when
it is absent there, keeping mode, owner and xattrs. A stateful file is one that is not a
symlink into `/etc/static`, not `/etc/static` itself, not one of setup-etc.pl's copies
(`/etc/.clean`), and not declared by the new generation.

Seeding happens once per upperdir (`/.rw-etc/.seeded`). An upperdir left by an earlier
overlay period that has since been left (`/.rw-etc/.exited`) is moved aside to
`/.rw-etc.stale-<t>` first.

**Carry-out, the rollback** (`features.nixos.etc-overlay.enable = lib.mkForce false`):
part of `features.nixos`, so present on every host and inert until an upperdir is left
to carry out.
- *Live:* the plain /etc under the overlay is reached through a non-recursive bind
  mount of /. Every upperdir entry the new generation does not declare is copied there,
  and deletions are applied: whiteouts, and carried-in files no longer in the upperdir.
  Then the overlay and its metadata are lazily unmounted, all before setup-etc.pl runs.
- *At boot:* the same, from the upperdir directly.

Either way, `/.rw-etc/.exited` is written afterwards.

**The gate** (`etc-overlay-live-switch`, drakkar's config, passed):
1. Boot without the feature and plant drakkar's state:
   - a `Wired connection 1` NM profile, tom's password, `adjtime`, `security/opasswd`;
   - `wpa_supplicant/imperative.conf` owned by nobody:nogroup, mode 664;
   - `mullvad-vpn/*`.
2. Switch live in, change state (a new NM profile, a deleted file), and switch live out.
3. Boot cold into the overlay (its own VM on the same disk), change state again, and
   boot cold out.

After every phase the test asserts:
- machine-id, every ssh host key, every planted file (content, mode, owner) and tom's
  shadow and passwd lines are unchanged;
- tom's password is accepted by PAM (`unix_chkpwd`), and a wrong one is refused;
- polkit and accounts-daemon are active, with no `217/USER`;
- no unit failed beyond the VM's baseline (vcache: no tailnet);
- vhealth, run as the `vhealth` user, has lost no probe that was up.

In the VM only the nix-daemon probe is up at baseline; the others need the host's
network.

**Caveats of a live switch**, either way: a process that opened an /etc file or watches
an /etc directory before the switch keeps the old (now hidden) one until it restarts or
reopens. switch-to-configuration restarts the units whose config changed, and the gate
found no failure from it. On drakkar, anything long-running outside that (the desktop
session) is still holding the old /etc until it is restarted. Generations built before
this feature carry nothing out: booting one after an overlay period brings back the /etc
from before it.

On the live host, the root-only part of the inventory that this could not see:

    sudo ls -la /etc/NetworkManager/system-connections
