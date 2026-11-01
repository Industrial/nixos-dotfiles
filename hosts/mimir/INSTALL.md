# Mimir Installation Guide

Mimir is the file server. Its layout lives in [`disko.nix`](./disko.nix): one NVMe for the
system, four HDDs carrying a **single btrfs RAID5 volume labelled `data`** (~55 TB usable, see
[`DATA.md`](./DATA.md)).

> **The data disks are in the layout, and the default install does not touch them.**
> `install-nixos mimir` applies the layout non-destructively — it creates only what is missing.
> An existing `/data` array is detected and left alone. Only `install-nixos mimir --wipe`
> destroys it, and that flag exists so the destruction is always something you typed.

## What the layout is

| Device | Partition | Contents |
| --- | --- | --- |
| `/dev/nvme0n1` | `disk-ssd-boot`, 512M | ESP, vfat, mounted `/boot`, `umask=0077` |
| `/dev/nvme0n1` | `disk-ssd-luks`, rest | LUKS `cryptroot` → btrfs, subvolumes `@root` → `/` and `@nix` → `/nix` |
| `/dev/sda` | `disk-hdd-a-data`, 100% | RAID5 member (partition only — not formatted individually) |
| `/dev/sdb` | `disk-hdd-b-data`, 100% | RAID5 member (partition only) |
| `/dev/sdc` | `disk-hdd-c-data`, 100% | RAID5 member (partition only) |
| `/dev/sdd` | `disk-hdd-d-data`, 100% | **The array**: `mkfs.btrfs -L data -m raid5 -d raid5` across all four |

Mimir declares no `@home` or `@var`; both live inside `@root`.

`/data` is mounted by [`filesystems.nix`](./filesystems.nix) from `LABEL=data`, not by disko.
The label is what makes the mount independent of which member device the kernel enumerates
first, and it is why the array must stay one labelled volume.

### Why the array is declared on the *last* disk

disko emits disks in attribute-name order and does no dependency tracking for multi-device
btrfs — `extraArgs` is an opaque string list. The `mkfs.btrfs` therefore has to run after every
member partition exists, which means it must sit on the alphabetically last disk. `hdd-a`,
`hdd-b` and `hdd-c` are declared `content = null` so disko creates and labels their partitions
without formatting them; `hdd-d` carries the `mkfs`. If you rename these disks, keep the one
holding `extraArgs` last, or the `mkfs` fails on a missing `by-partlabel` path.
`disko.assay.nix` asserts this.

## Why the default install is safe for /data

Nothing in disko's **format** phase is unconditional:

- `sgdisk --clear` runs only `if ! blkid "$disk"` — i.e. only on a disk with no signature at all.
- Partition creation is attempted and, when the partition already exists, falls back to
  re-applying the GUID/name/typecode. Boundaries are not moved.
- `mkfs.btrfs` runs only `if ! blkid "$device" -o export | grep -q '^TYPE='`. An existing array
  reports `TYPE=btrfs` and is skipped.

All the destruction lives in the **destroy** phase, which is what `--wipe` adds: it runs
`wipefs --all -f` on every partition and `dd if=/dev/zero bs=440 count=1` over each MBR.

## Reinstalling (keeping /data)

1. Build the installer ISO and write it to a USB stick:

   ```bash
   bin/flash-installer --list        # show removable candidates
   bin/flash-installer /dev/sdX      # build, confirm, write, verify
   ```

   Use the helper rather than raw `dd`: it refuses any target that is not a present, removable,
   whole USB disk, and verifies the write by reading the stick back.

2. Boot mimir from the stick, then get on the network: `nmtui`.

3. Run the installer. It clones this repo from GitHub, so push first:

   ```bash
   install-nixos mimir
   ```

   It prints every disk the host declares, says which mode it is in, asks once, prompts for the
   LUKS passphrase, applies the layout, and runs `nixos-install`.

4. Set passwords **before** rebooting:

   ```bash
   nixos-enter --root /mnt -c 'passwd'
   nixos-enter --root /mnt -c 'passwd tom'
   reboot
   ```

   Not optional: no host declares a password, so both accounts are created locked, and there is
   no console autologin. `tom`'s key from the other fleet hosts is in `authorized_keys` and
   `tom` has `NOPASSWD: ALL` sudo, so SSH is the recovery path if you reboot too early.

## After first boot

```bash
btrfs filesystem show /data        # expect ONE filesystem labelled 'data' with 4 devices
btrfs filesystem df /data          # expect Data: RAID5, Metadata: RAID5
findmnt /data                      # expect LABEL=data, compress=zstd
findmnt /                          # expect subvol=@root, NOT subvolid=5
ls /data                           # expect archive/ docker/ scratch/ cache/
```

If `btrfs filesystem show` reports four separate single-device filesystems, the array was
created by an older revision of this config — that is the bug this layout fixes, and
recovering means rebuilding the array (destructive).

## Known gap: /data has no `nofail`

`fileSystems."/data"` is `LABEL=data` with `["compress=zstd" "defaults"]`. If the array is
missing or degraded past mounting, the mount unit fails, `local-fs.target` fails, and a headless
mimir drops to an emergency shell you cannot reach over SSH. A fresh install creates the array,
so this does not bite the install path — but a failed disk later will.

Adding `nofail` trades that for the opposite risk: mimir boots, `/data` is an empty directory,
and the NFS server happily exports it. Decide which failure you prefer before a disk dies, not
after.

## Troubleshooting

- **`mkfs.btrfs: No such file or directory`** on a `by-partlabel` path — the array's `mkfs` ran
  before a member partition existed. Check that the disk carrying `extraArgs` still sorts last.
- **`/data` will not mount after a disk failure** — RAID5 needs `-o degraded` to mount with a
  member missing. Mount it by hand from the emergency shell, then replace the disk and
  `btrfs replace`.
- **Starting over on the system disk only** — `cryptsetup close cryptroot`,
  `wipefs -a /dev/nvme0n1`, then rerun `install-nixos mimir`. This leaves `/dev/sd[a-d]`
  untouched.
