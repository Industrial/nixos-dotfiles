# Huginn Installation Guide

Huginn is the [StarLite 5](https://us.starlabs.systems/products/starlite) tablet. Its disk layout
lives in [`disko.nix`](./disko.nix) and is applied by disko, so a reinstall is reproducible and
needs no manual partitioning.

## What the layout is

One NVMe disk, `/dev/nvme0n1`:

| Partition | Size | Contents |
| --- | --- | --- |
| `disk-ssd-boot` | 512M | ESP, vfat, mounted `/boot` with `umask=0077` |
| `disk-ssd-luks` | rest | LUKS container `cryptroot` → btrfs |

Inside the btrfs volume:

| Subvolume | Mountpoint | Mount options |
| --- | --- | --- |
| `@root` | `/` | `compress=zstd,noatime` |
| `@nix` | `/nix` | `compress=zstd,noatime` |
| `@home` | `/home` | `compress=zstd,noatime` |
| `@var` | `/var` | `compress=zstd,noatime` |
| `@swap` | `/swap` | `noatime` — holds a 20G swapfile for hibernation |

Three things differ from the other hosts, all for tablet reasons: zstd compression (smallest disk
in the fleet, and it doubles as the dev scratch disk), `noatime` everywhere (every atime update is
an NVMe write), and the hibernation swapfile (a tablet gets closed and carried, and
suspend-to-RAM alone drains the battery).

## Reinstalling

1. Build the installer ISO and write it to a USB stick, from a machine with the repo checked out:

   ```bash
   nix build .#installer-iso
   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M conv=fsync status=progress
   ```

   Replace `/dev/sdX` with the stick — confirm it with `lsblk` first, because `dd` will not ask.

2. Boot the tablet from the stick. Attach the keyboard; the installer is a console environment.
   On Star Labs firmware, hold `F7` (or `Esc` for the full menu) at power-on to pick the USB
   device.

3. Get on the network. The ISO ships NetworkManager:

   ```bash
   nmtui
   ```

4. Run the installer. It clones this repo from GitHub, so it installs whatever is on `main` —
   push your changes before you start:

   ```bash
   install-nixos huginn
   ```

   It will show the current disk layout, ask for confirmation, prompt for the LUKS passphrase,
   apply the layout with the disko version pinned in this repo's `flake.lock`, then run
   `nixos-install`.

5. Set passwords and reboot:

   ```bash
   nixos-enter --root /mnt -c 'passwd'
   nixos-enter --root /mnt -c 'passwd tom'
   reboot
   ```

## After first boot

- **Verify hibernation.** `boot.resumeDevice` is set in [`hardware.nix`](./hardware.nix), and
  systemd records the swapfile's physical offset in the `HibernateLocation` EFI variable when it
  hibernates, so resume should work with no further configuration. Confirm it:

  ```bash
  swapon --show            # /swap/swapfile should be listed
  systemctl hibernate      # then power back on and check you came back, not booted fresh
  ```

  If it boots fresh instead of resuming, pin the offset explicitly — get it with

  ```bash
  sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
  ```

  and add `boot.kernelParams = ["resume_offset=<n>"];` to `hardware.nix`. A missing or stale
  offset only costs a failed resume attempt and a normal boot; it cannot corrupt the filesystem.

- **Verify video acceleration.** Huginn imports
  [`features/nixos/graphics/intel.nix`](../../features/nixos/graphics/intel.nix), not the `amd.nix`
  the rest of the fleet uses, because the StarLite 5 is an Intel N200 (Alder Lake-N):

  ```bash
  vainfo | head            # should report the iHD driver, not i965 and not a software fallback
  ```

- **Enroll the host key** for `deploy-rs` pushes if the reinstall generated a new one — see
  `features/fleet/operator-ssh.nix`.

## Troubleshooting

- **Disko refuses to wipe.** It needs `--yes-wipe-all-disks`; `install-nixos` already passes it.
  If a previous attempt left mappings open, `cryptsetup close cryptroot` and
  `wipefs -a /dev/nvme0n1`, then retry.
- **The live store runs out of space.** The ISO's Nix store is RAM-backed. Nothing large should
  build there — if something does, check that the binary caches in the repo's `nixConfig` are
  reachable from the network you joined in step 3.
- **Installed but will not boot.** Check the ESP actually got the loader:
  `ls /mnt/boot/EFI/systemd`. Star Labs firmware will also need `Secure Boot` off.
