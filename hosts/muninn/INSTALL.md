# Muninn Installation Guide

Muninn is an Intel machine (`kvm-intel` in [`hardware.nix`](./hardware.nix)) that acts as the
monitoring standby for mimir. Its disk layout lives in [`disko.nix`](./disko.nix) and is
applied by disko, so a reinstall needs no manual partitioning.

## What the layout is

One NVMe disk, `/dev/nvme0n1`:

| Partition | Size | Contents |
| --- | --- | --- |
| `disk-ssd-boot` | 512M | ESP, vfat, mounted `/boot` with `umask=0077` |
| `disk-ssd-luks` | rest | LUKS container `cryptroot` → btrfs |

Inside the btrfs volume:

| Subvolume | Mountpoint |
| --- | --- |
| `@root` | `/` |
| `@nix` | `/nix` |
| `@home` | `/home` |
| `@var` | `/var` |

No swap and no bulk disk. The volume has no top-level mountpoint; the comment in `disko.nix`
explains why. `disko.assay.nix` pins the layout. The only other filesystem is the NFS
automount of mimir in [`filesystems.nix`](./filesystems.nix); see [`DATA.md`](./DATA.md).

## Reinstalling

1. Build the installer ISO and write it to a USB stick, from a machine with the repo checked
   out:

   ```bash
   bin/flash-installer --list        # show removable candidates
   bin/flash-installer /dev/sdX      # build, confirm, write, verify
   ```

   Use the helper rather than raw `dd`: it refuses any target that is not a present,
   removable, whole USB disk, and verifies the write by reading the stick back.

2. Boot muninn from the stick and get on the network: `nmtui`.

3. Run the installer. It clones this repo from GitHub, so it installs whatever is on `main`;
   push your changes first:

   ```bash
   install-nixos muninn
   ```

   It lists the disk, asks once, prompts for the LUKS passphrase, applies the layout with
   the disko version pinned in `flake.lock`, and runs `nixos-install`. Muninn has one disk,
   so `--wipe` only matters if the NVMe holds a layout you want destroyed rather than reused.

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
findmnt /                              # expect subvol=@root, NOT subvolid=5
systemctl status prometheus grafana    # the monitoring standby
```

- **Enroll the host key** for `deploy-rs` pushes if the reinstall generated a new
  `~/.ssh/id_ed25519`: update muninn's slot in `features/fleet/operator-ssh.nix`.
- **CI does not evaluate muninn.** The `check` matrix covers drakkar, huginn and mimir only,
  so check the configuration locally before installing:
  `nix build --dry-run .#nixosConfigurations.muninn.config.system.build.toplevel`.

## Troubleshooting

- **Disko refuses to wipe.** Only relevant with `--wipe`, which passes
  `--yes-wipe-all-disks` for you. If a previous attempt left mappings open,
  `cryptsetup close cryptroot` and `wipefs -a /dev/nvme0n1`, then retry.
- **`/mnt/mimir` is empty.** Expected today: mimir does not export to muninn. See
  [`DATA.md`](./DATA.md).
- **Installed but will not boot.** Check the ESP got the loader: `ls /mnt/boot/EFI/systemd`.
