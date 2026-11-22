# /etc: setup-etc.pl against `system.etc.overlay` on drakkar (GH-185)

A measurement, not a change. No host enables the overlay, and there is no feature option.
Whether to build one (with the copy-before-first-boot step below) is still open on #185.

## The test

`features/nixos/etc-overlay/test.nix`, with its colocated suite `test.assay.nix`:

    nix build .#checks.x86_64-linux.etc-overlay-stock   # setup-etc.pl
    nix build .#checks.x86_64-linux.etc-overlay-on      # system.etc.overlay, mutable

CI does not build VM tests on PRs. Run them locally through the serialized VM wrapper.

The node is drakkar's own `hosts/drakkar/configuration.nix`, with every profile and host
feature (userborn included). It differs from the host in three ways:
- `disko.nix` is disabled, because its LUKS/btrfs layout cannot exist in a VM.
- `services.timesyncd.enable` and `DefaultTimeoutStartSec` are forced, because they
  conflict with qemu-vm.
- The test adds an `alt` specialisation, one /etc file apart, to switch between, and in
  the stock variant an `overlay` specialisation.

A wrapper around the `etc` activation snippet logs `gh185-etc-step ns=<n>` to the journal.

## Numbers

These are from main at 3131c7f9, VM with 4 vCPU and 6 GiB, 10 switches per variant.

| | setup-etc.pl | overlay (mutable) |
|---|---|---|
| `/etc` step per switch, median (min to max) | 173.4 ms (115 to 245) | 147.1 ms (129 to 243) |
| whole `switch-to-configuration test`, median | 5.09 s | 4.88 s |
| `/etc` step at boot | 167 ms in `initrd-nixos-activation` | 2.5 ms (skipped); the initrd mounts the erofs metadata image (~34 ms) and runs `rw-etc` (~31 ms) |
| boot (systemd-analyze) | 11.1 s | 10.8 s |

An earlier run at fd9eb137 on a busier host gave 197.5 ms against 129.7 ms per step,
and 7.85 s against 3.43 s per switch. That wall-time gap was host noise; it did not
come from /etc.

Every switch in both variants returned rc=4, and in both the only failed unit is
`vcache.service`, which has no tailnet in a VM.

Reading: setup-etc.pl is not a bottleneck at drakkar's size (174 `environment.etc`
entries). The overlay saves tens of milliseconds per switch, so a Rust rewrite of
setup-etc.pl would buy about the same.

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
stock test's last subtest switches into the `overlay` specialisation, with these results:
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

So adopting the overlay needs these steps:
1. Copy every stateful file above (non-symlink, not owned by `/etc/.clean`, with its
   mode and owner) from the old /etc into `/.rw-etc/upper` **before the first overlay
   boot**.
2. Enable it with `boot` and a reboot, never with a live `switch`.
3. Keep rollback simple: a pre-overlay generation boots setup-etc.pl over the old
   /etc, which is still untouched underneath.
