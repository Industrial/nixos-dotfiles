# userborn (users and groups without update-users-groups.pl)

`features.nixos.users.userborn.enable` (in `features/nixos/users/default.nix`) turns on
nixpkgs' `services.userborn`. It replaces the Perl activation script
`update-users-groups.pl` with userborn, a Rust program that runs as `userborn.service`.
Like the Perl script, it writes `/etc/passwd`, `/etc/group` and `/etc/shadow`. It is **off
everywhere**, and turning it on for a host is a separate change made only after the operator
agrees to it (GH-187). Root is locked (ADR-0007), so a broken user database can lock you out
of the box.

## What was measured

`features/nixos/users/test.nix` builds a VM with drakkar's user and access modules: users,
sudo, pam, ssh, operator-ssh and nushell. `users.mutableUsers` is left at `true`. The VM is
tested three ways:

| Check | `.#checks.x86_64-linux.users-vm-perl` | `users-vm-userborn` | `users-vm-migrate` (perl → userborn → perl) |
|-------|------|----------|---------|
| operator: uid 1000, groups, nushell, hash, home | ok | ok | ok |
| root locked (`!`), root SSH refused | ok | ok | ok |
| a root password set by hand is locked again at the next switch | ok | ok | ok |
| operator SSH key login, `sudo -n` over SSH | ok | ok | ok |
| console (tty) password login | ok | ok | ok |
| switch that adds a user and a group, then rollback | ok | ok | ok |
| `pwck -r`, `grpck -r` after boot, switch and rollback | clean | clean | clean |

Run one with
`bin/with-devenv bash .tmp/vnla/vmtest.sh <worktree> '.#checks.x86_64-linux.users-vm-userborn'`.
CI does not build the VM tests.

## Differences that matter

- **Boot ordering.** userborn is a unit that runs after the activation snippets. On a fresh
  install the snippets therefore find no `/etc/shadow`. The root-lock snippet now skips in
  that case, and with userborn on, `lock-root-password.service` repeats the lock once
  `userborn.service` has written the files. On an installed host `/etc/shadow` already
  exists, so the snippet behaves exactly as it does now.
  `linkNushellConfig` (`features/cli/nushell`) still fails on a fresh userborn install,
  because its `chown tom` runs before `tom` exists. It does no harm on an installed host.
- **A user removed from the config** (when the generation that declared it is rolled back):
  - the Perl script deletes the user and the group;
  - userborn keeps the entry, sets its password to `!*` (locked), and removes it from its
    groups. The group itself stays.
  - **userborn → Perl rollback:** Perl never saw that user, so it leaves it **active**, with
    its password and group memberships. After rolling back to Perl, remove by hand any user
    that was added while userborn was on (see below).
- userborn logs `uses an insecure password hashing scheme` for `$6$` (sha512crypt) hashes.
  It is only a warning. Running `passwd` writes a new hash in the system's default scheme.

## Switching a host over

1. Before you start, open a second root shell (`sudo -i`) and keep it open.
2. Set `features.nixos.users.userborn.enable = true;` in `hosts/<host>/configuration.nix`,
   then deploy. On first start, `userborn-import-legacy.service` imports the Perl state
   (`/var/lib/nixos/uid-map` and the declarative lists), so uids and gids keep their
   numbers.
3. Check:
   - `systemctl is-active userborn.service lock-root-password.service`
   - `sudo pwck -r` and `sudo grpck -r`
   - `sudo getent shadow root`: the hash field starts with `!`
   - `id tom`
   - `ssh tom@<host> sudo -n true` from another fleet host
4. **At the console:** log in as `tom` with the password, on a tty (Ctrl+Alt+F3), not
   through the desktop session. Only once that works, close the shell from step 1.

## Rollback

1. Set the option back to false and deploy. Or, from the shell you kept open,
   `sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch` with the
   generation from before the switch. Or pick that generation in the systemd-boot menu.
2. The Perl script takes over again. It keeps every entry userborn wrote, so the operator
   and root are unchanged.
3. Look for users created while userborn was on: `awk -F: '$3 >= 1000 && $3 < 60000' /etc/passwd`.
   `sudo userdel <name>` any that are no longer declared.
4. `sudo rm -rf /var/lib/userborn` only if you want the next switch-over to import the Perl
   state again.

If login is broken anyway, use ADR-0007's "Recovery (locked root)": an older generation
from the boot menu, then the `SYSTEMD_SULOGIN_FORCE=1` emergency shell, then the live USB.
