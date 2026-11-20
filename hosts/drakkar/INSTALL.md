# Drakkar Installation Guide

Drakkar is the desktop workstation and gaming station (Gigabyte X870E AORUS MASTER, AMD).
Its disk layout lives in [`disko.nix`](./disko.nix) and is applied by disko, so a reinstall
needs no manual partitioning.

> **The `/data` HDD is in the layout, and the default install does not touch it.**
> `install-nixos drakkar` applies the layout non-destructively: it creates only what is
> missing and skips a disk that already carries a filesystem. Only
> `install-nixos drakkar --wipe` destroys `/data`.

## What the layout is

| Device | Partition | Contents |
| --- | --- | --- |
| `/dev/nvme0n1` | `disk-ssd-boot`, 512M | ESP, vfat, mounted `/boot` with `umask=0077` |
| `/dev/nvme0n1` | `disk-ssd-luks`, rest | LUKS `cryptroot` → btrfs |
| `/dev/sda` | `disk-hdd-data`, 100% | btrfs, mounted `/data`, no subvolumes, not encrypted |

Inside the LUKS btrfs volume:

| Subvolume | Mountpoint |
| --- | --- |
| `@root` | `/` |
| `@nix` | `/nix` |
| `@home` | `/home` |
| `@var` | `/var` |

The LUKS volume deliberately has no top-level mountpoint; the comment in `disko.nix` explains
why one would misplace `/` on reinstall. `disko.assay.nix` pins the layout.

## Reinstalling

1. Build the installer ISO and write it to a USB stick, from a machine with the repo checked
   out:

   ```bash
   bin/flash-installer --list        # show removable candidates
   bin/flash-installer /dev/sdX      # build, confirm, write, verify
   ```

   Use the helper rather than raw `dd`: it refuses any target that is not a present,
   removable, whole USB disk, and verifies the write by reading the stick back.

2. Boot drakkar from the stick. Drakkar is **wired-only**: `hardware.nix` blacklists the WiFi
   driver on the installed system, so plug in Ethernet. The installer ISO ships
   NetworkManager (`nmtui`) if you need to configure the link.

3. Run the installer. It clones this repo from GitHub, so it installs whatever is on `main`;
   push your changes first:

   ```bash
   install-nixos drakkar
   ```

   It lists every disk the host declares, says which mode it is in, asks once, prompts for
   the LUKS passphrase, applies the layout with the disko version pinned in `flake.lock`,
   and runs `nixos-install`.

4. Set passwords **before** rebooting, then reboot:

   ```bash
   nixos-enter --root /mnt -c 'passwd'
   nixos-enter --root /mnt -c 'passwd tom'
   reboot
   ```

   Not optional: no host declares a password, so both accounts are created locked, and
   there is no console autologin. `tom`'s key from the other fleet hosts is in
   `authorized_keys` and `tom` has `NOPASSWD: ALL` sudo, so SSH from another host is the
   recovery path if you reboot too early.

## After first boot

```bash
findmnt /                  # expect subvol=@root, NOT subvolid=5
findmnt /data              # expect the /dev/sda btrfs
ls -d /data/cache /data/Games
rfkill list wifi           # expect "Soft blocked: yes", or no device at all
```

- **Enroll the host key** for `deploy-rs` pushes if the reinstall generated a new
  `~/.ssh/id_ed25519`: update drakkar's slot in `features/fleet/operator-ssh.nix`.
- **Remote builds.** Mimir offloads builds here. Check from mimir with
  `docs/runbooks/nix-remote-build.md`.

## Troubleshooting

- **Disko refuses to wipe.** Only relevant with `--wipe`, which passes
  `--yes-wipe-all-disks` for you. If a previous attempt left mappings open,
  `cryptsetup close cryptroot` and retry.
- **Starting over on the system disk only.** `cryptsetup close cryptroot`,
  `wipefs -a /dev/nvme0n1`, then rerun `install-nixos drakkar`. This leaves `/dev/sda`
  alone.
- **Installed but will not boot.** Check the ESP got the loader: `ls /mnt/boot/EFI/systemd`.
