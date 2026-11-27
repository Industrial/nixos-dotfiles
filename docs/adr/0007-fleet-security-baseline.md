# ADR-0007: A fleet-wide security baseline, and what stays operator-gated

**Status:** Accepted
**Date:** 2026-11-20
**Issue:** #116 (Security hardening, 64 → 100)
**Relates to:** ADR-0003 (STIG is the single source of kernel hardening), ADR-0004 (STIG
baseline on mimir only). This ADR narrows neither of them. It adds a second, smaller STIG
profile, and it is the "explicit, non-STIG decision" ADR-0003 asks for, for the kernel
settings below.

## Context

The #116 audit scored the security area 64/100. It found these gaps:

1. The operator user is in `nix.settings.trusted-users`, which is root-equivalent.
2. Root's `initialHashedPassword` was the hash of `"test"`.
3. The STIG baseline is mimir-only (ADR-0004). drakkar, huginn and muninn carry nothing.
4. No Secure Boot, LUKS not on every disk, no TPM2 unlock.
5. Kernel/sysctl/systemd hardening breadth unverified.

Verifying item 5 turned up a concrete bug. `features/nixos/boot/default.nix` listed its
security sysctls in `boot.kernelParams`, as bare strings like
`"net.ipv4.conf.all.accept_redirects=0"`. The kernel only reads sysctls from its command line
as `sysctl.<name>=…`. Bare names go to init as unused arguments. **None of those settings ever
reached a host.** The same applies to the module's memory and network tuning in the same list.

Two earlier changes are prior art and shape the decisions:

- **PR #103** (`71b0ef30`, merged) removed `trusted-users = ["root" "@wheel"]` from
  `features/nixos/default.nix`. That was the broader of two grants: it trusted every wheel
  member. It left the operator-only grant in `features/nixos/users`. That grant is
  deliberate, because deploy-rs and the remote builder depend on it (see decision 2). This ADR
  builds on #103 and keeps the trust at one site, one user.
- **PR #108** (`secure-boot-implementation`, open) adds `features/nixos/secure-boot` and
  imports it from `profiles/base.nix`. It sets `boot.loader.secureBoot.*`, and no NixOS
  module declares those options, so every host would fail to evaluate. Its import would also
  turn it on fleet-wide. Decision 6 is the off-by-default, lanzaboote-based replacement. #108
  should be closed in favour of it, or reworked to set `features.hardening.secureBoot`.
  GH-184 has since wired the lanzaboote input and module behind that option, which
  supersedes the branch.

## Decisions

### 1. Root is locked

`users.users.root.hashedPassword = "!"` replaces the `"test"` hash. With mutable users (the
fleet default) NixOS never rewrites an existing `/etc/shadow` entry, so declaring the hash
alone would not lock any installed host. An activation script (`lockRootPassword`, after
`users`) therefore runs `usermod -L root`. That prefixes the stored hash with `!`, so it is
reversible with `passwd -u root`.

Interlock: the script locks root only if the operator account has a real crypt hash
(`$…`). Otherwise it warns and leaves root alone, so a host never loses both its root
password and its password-sudo path. Opt out per host with
`features.hardening.lockRoot = false`.

The operator's own `initialHashedPassword` (also `"test"`) stays. It only applies when the
account is created, so on installed hosts it has long been replaced. A fresh install needs a
usable first login. Replacing it with `hashedPasswordFile` belongs with secrets management,
which is out of scope (see follow-ups).

### 2. Operator trust stays, behind a signing path

The operator stays in `trusted-users` by default. Two dependencies were traced:

| Path | Why it needs trust |
|------|--------------------|
| deploy-rs (`flake.nix` `mkDeployNode`, `sshUser = "tom"`) | copies the closure with `nix copy --no-check-sigs`. The daemon honours that flag for trusted users only, and paths built on the deploying host are unsigned. |
| remote builder (`features/fleet/nix-remote-builder-*`, `sshUser = settings.username`) | the daemon refuses to build input-addressed derivations for untrusted users. |

Removing the trust without replacing it breaks every deploy. The replacement is store-path
signing, which ships OFF:

- `features.hardening.storeSigning.{enable,secretKeyFile,publicKeys}` sets
  `secret-key-files` (every local build is signed) and adds the fleet's public keys to
  `trusted-public-keys`.
- `features.hardening.operatorTrusted = false` takes the operator out of `trusted-users`. An
  assertion refuses it unless signing is enabled.

A related point is in someone else's file. `features/fleet/operator-ssh.nix` gives the
operator `NOPASSWD: ALL` sudo, which is root-equivalent with or without `trusted-users`.
Dropping the Nix trust is worth doing because it makes store integrity depend on a
signature, not on the account. It does not make the operator unprivileged. That file belongs
to another workstream, so narrowing the sudo rule is a follow-up.

### 3. Kernel and network sysctls (non-STIG, fleet-wide)

These go in `boot.kernel.sysctl`, all `mkDefault`, in `features/nixos/boot`:

| Setting | Value | Why it is safe on drakkar/huginn/muninn/mimir |
|---------|-------|-----------------------------------------------|
| `kernel.dmesg_restrict` | 1 | wheel still reads the kernel log with `journalctl -k` |
| `kernel.unprivileged_bpf_disabled` | 1 | nothing loads BPF without root. Steam, Wine and Docker don't. |
| `net.core.bpf_jit_harden` | 2 | JIT constant blinding. Negligible cost. |
| `net.ipv{4,6}.conf.{all,default}.accept_redirects` | 0 | no host relies on ICMP redirects |
| `net.ipv4.conf.{all,default}.secure_redirects`, `send_redirects` | 0 | no host is a router. Docker/Tailscale never forward back out the ingress interface. |
| `net.ipv{4,6}.conf.{all,default}.accept_source_route` | 0 | matches systemd's default, made explicit |
| `net.ipv4.conf.{all,default}.log_martians` | 1 | rate-limited kernel log only |
| `net.ipv4.tcp_rfc1337` | 1 | TIME-WAIT assassination protection |

Unused network protocol modules are blacklisted from autoloading: dccp, sctp, rds, tipc,
n-hdlc, ax25, netrom, x25, rose, decnet, econet, af_802154, ipx, appletalk, psnap, p8023,
p8022, can, atm. The block had been commented out. WebRTC uses userspace SCTP, so the kernel
`sctp` module isn't needed.

The STIG-owned keys (`kptr_restrict`, `randomize_va_space`, `tcp_syncookies`) are **not** set
here (ADR-0003). They come from the STIG controls in decision 5. nixpkgs already defaults
`kptr_restrict` to 1.

**Evaluated and skipped**, with the reason:

| Setting | Why not |
|---------|---------|
| `kernel.unprivileged_userns_clone = 0` / restricting user namespaces | Steam's pressure-vessel, bubblewrap/Flatpak, Chromium's sandbox and rootless Docker (`features/nixos/docker`) all need them |
| `kernel.yama.ptrace_scope` ≥ 2 | breaks `gdb -p` and debugger attach (`mcp-debugger attach_to_process`), and some Wine/anti-cheat paths. The kernel's Yama default (1) is left alone. |
| `rp_filter = 1` (strict) | breaks Tailscale and Docker asymmetric routing. The NixOS firewall's `checkReversePath` already does reverse-path filtering in netfilter. |
| `accept_ra = 0` | kills IPv6 SLAAC on hosts that take their address from router advertisements |
| `fs.suid_dumpable = 0` | systemd-coredump's 2 already pipes setuid cores to a root-only handler. 0 only loses crash data. |
| `kernel.sysrq = 0` | the default 16 (sync only) can neither leak nor kill anything, so 0 buys nothing |
| `kernel.kexec_load_disabled`, `security.protectKernelImage`, `lockKernelModules` | ADR-0003: break hibernation on huginn and hot-plugged/VM modules |
| `init_on_alloc`/`init_on_free`, `slab_nomerge`, `lockdown=` | measurable CPU/memory cost on the gaming host. `lockdown=` also blocks unsigned modules (NVIDIA). Revisit with Secure Boot. |
| `kptr_restrict = 2` | V-268160 is an equality test against 1 (ADR-0003). 2 is a finding. |

### 4. SSH

The nixpkgs 26.11 defaults are already modern: ML-KEM/sntrup hybrid and curve25519 key
exchange, AEAD ciphers, ETM SHA-2 MACs. Pinning a local copy would only let it go stale, so
`features/network/ssh` does not pin them. Its suite instead asserts on the evaluated lists that
no CBC, 3DES/arcfour, SHA-1, NIST-curve kex or truncated MAC is offered. Added:
`LogLevel VERBOSE` (logs the key fingerprint, same as V-268088), `LoginGraceTime 30`,
`MaxStartups 10:30:60`. Agent and TCP forwarding stay on, because pam `sshAgentAuth` and
remote development use them.

**sshguard, not fail2ban.** sshguard is already enabled with the Tailscale range
whitelisted. fail2ban would parse the same log a second time and add nothing for a key-only
server.

**systemd sandboxing.** sshd can't be meaningfully sandboxed, because it has to spawn full
user sessions. tailscaled needs `CAP_NET_ADMIN` and tun. The network-facing services that
*can* be sandboxed (searx, qbittorrent, the media stack, the RustDesk relay) live outside this
ticket's scope and are listed as a follow-up, to be measured with `systemd-analyze security`.

### 5. STIG: a fleet-baseline profile

`features/security/stig/profiles/fleet-baseline.nix` carries the 15 base-safe controls that
cost an interactive host nothing:

V-268078 firewall · V-268131 telnet absent · V-268141 syncookies · V-268151 time sync ·
V-268173 AppArmor · V-268154 require-sigs · V-268156 sudo password · V-268160 kptr_restrict ·
V-268161 ASLR · V-268088 SSH VERBOSE · V-268137 no root SSH · V-268142/V-268143 ClientAlive ·
V-268159 sshd · V-268176 SSH via PAM.

Kept mimir-only, with the cost on a workstation:

| Control(s) | Cost on a workstation |
|------------|-----------------------|
| audit set (V-268080, V-268091, V-268094–100, …) | the ADR-0004 stalls |
| V-268089 / V-268157 cipher/MAC pins | narrower and weaker than the nixpkgs defaults (ADR-0004) |
| V-268130 ENCRYPT_METHOD SHA512 | a downgrade from the yescrypt default |
| V-268085 maxlogins 10 | deploy-rs and remote builds open parallel SSH sessions as the operator |
| V-268181 UMASK 077 | breaks the shared `/data` and `/games` group directories |
| pwquality (6), V-268171 FAIL_DELAY, V-268087 vlock, V-268150 polling | interactive friction with no security value outside an accredited host |

The profile is a strict subset of base-safe. Its `profile` and `implemented` are `mkDefault`,
so on mimir (which will import both) base-safe's metadata wins and mimir's report is
unchanged. The suite asserts the subset, the exclusions and the merged result.

**Wiring is a follow-up.** It takes two lines in files owned by another workstream:
`./security/stig/profiles/fleet-baseline.nix` in `features/catalog.nix`, which declares
`features.security.stig.profiles.fleet-baseline.enable`, and that enable set to `true` in
`profiles/base.nix`. `lib/features.nix` keys each wrapped module by its file, so on mimir the
control modules shared with base-safe are evaluated once. That combination was evaluated on
mimir and drakkar in PR #125. Until it is wired, the three interactive hosts keep reporting
profile `none`. Most of
these controls are already satisfied in substance there through `features/nixos/networking`,
`features/security/apparmor`, `features/nixos/security/sudo` and `features/network/ssh`.

### 6. Physical-access items: options OFF, runbooks below

| Option | Module | Default |
|--------|--------|---------|
| `features.hardening.secureBoot.enable` | `features/nixos/boot` (lanzaboote) | off |
| `features.hardening.tpm2Unlock.enable` | `features/nixos/boot` (systemd-cryptenroll token on `cryptroot`) | off |
| `features.hardening.storeSigning.enable` | `features/nixos/users` | off |
| data-disk encryption | runbook only (see below) | n/a |

All four hosts already have a LUKS root (`hosts/<name>/disko.assay.nix`). What lacks LUKS is
the **data** disks: drakkar's `/data` HDD and mimir's four-disk btrfs RAID5 `/data`
(~55 TB). Encrypting either is destructive, so it is runbook-only. A disko option was
considered and rejected. `disko.nix` is also evaluated standalone by the disko CLI during
installs, where `config.features.*` does not exist. And a flag that describes a layout the
disk doesn't have yet makes `/data` fail to mount the moment someone flips it.

The systemd-boot **editor stays enabled** while Secure Boot is off. It is the locked-root
recovery path (below), and turning it off buys nothing without Secure Boot. The root is LUKS,
so an edited command line still stops at the passphrase prompt, and the ESP is unsigned and
writable by anyone at the machine anyway. The Secure Boot option disables it.

## Recovery (locked root)

In order of preference:

1. **sudo as the operator.** `sudo -i`. The operator has password sudo through wheel and,
   today, `NOPASSWD` through `features/fleet/operator-ssh.nix`.
2. **Previous generation.** Pick an older entry in the systemd-boot menu (10 are kept).
3. **Emergency shell with root locked.** sulogin refuses a locked root. At the systemd-boot
   menu press `e` and append `systemd.setenv=SYSTEMD_SULOGIN_FORCE=1 systemd.unit=rescue.target`
   (or `emergency.target`). sulogin then opens a root shell without a password. This is why
   the editor stays on.
4. **Live USB.** Boot the installer ISO (`nix build .#installer-iso`), `cryptsetup open` the
   root, mount the subvolumes, `nixos-enter`, then `passwd -u root` or fix the operator account.
5. **Undo the lock.** `sudo passwd -u root` restores the previous hash. Set
   `features.hardening.lockRoot = false` on that host first, or the next activation re-locks it.

## Runbook: store-path signing (removes operator trust)

1. On every host: `sudo mkdir -p /var/lib/nix-signing && sudo nix key generate-secret --key-name <host>-1 | sudo tee /var/lib/nix-signing/secret-key >/dev/null && sudo chmod 0400 /var/lib/nix-signing/secret-key`,
   then `sudo nix key convert-secret-to-public < /var/lib/nix-signing/secret-key`.
2. Commit all four public keys. Set `features.hardening.storeSigning = { enable = true; publicKeys = [ … ]; }`
   fleet-wide, and deploy with the operator still trusted.
3. Sign what is already in each store: `sudo nix store sign --all --key-file /var/lib/nix-signing/secret-key`.
4. Set `checkSigs = true` on the deploy-rs profile (`flake.nix`), and move the remote builder
   clients from `sshUser = tom` to a forced-command `nix.sshServe` user (`features/fleet`).
5. Only then set `features.hardening.operatorTrusted = false`, and deploy to **one** host
   first. Check that a deploy *to* it and a remote build *on* it both still work before
   rolling out.

## Runbook: Secure Boot (lanzaboote)

The `lanzaboote` flake input (nix-community/lanzaboote, pinned to a release tag, every input
following ours) is in `flake.nix` since GH-184. `features/nixos/boot` imports its module on
every host, where it stays inert until the option is on. With the option on, lanzaboote's
`lzbt` replaces the Python systemd-boot installer: it reads each generation's bootspec,
writes signed UKIs to `/boot/EFI/Linux/`, and keeps the same 10-generation limit.
`lzbt` runs through our own install hook, `lzbt-all-profiles` in `features/nixos/boot`, not
upstream's. Upstream's hook only sees `/nix/var/nix/profiles/system-*-link` and leaves
`default nixos-*`, so the highest version number wins. comin deploys through
`system-profiles/comin`, and a host can carry another profile's generations (muninn's
`system-10` from the install and its `comin-*` from before vdeploy; drakkar's old
`system-profiles/comin-*`).
Our hook passes every profile's generations, as the Python installer does, and writes the
generation being switched to as `default` in `loader.conf`, matched by its toplevel, so
generation numbers that collide across profiles do not matter.

The hosts are deployed differently, and that changes where a missing key fails:

| Host | Deployer | What it runs on merge | Where `lzbt` runs |
|------|----------|-----------------------|-------------------|
| muninn (first), drakkar | vdeploy (muninn since #437) | `switch-to-configuration test`, vhealth, `nix-env -p system --set X`, then `switch-to-configuration boot` (`rust/tools/vdeploy/src/apply.vlt`) | in the last step, after X is live and healthy. With `createKeys` (muninn), `sbctl-keys.service` has already created the keys in the `test` step |
| a host still on comin | comin | `nix-env -p system-profiles/comin --set X`, then `X/bin/switch-to-configuration switch` | inside `switch`, which installs the bootloader BEFORE activating: a missing key fails comin's switch, the host stays on the previous generation and the ESP is untouched; only `system-profiles/comin` already names X |

Three VM tests run this runbook through OVMF and the ESP, each host's layout and hardening:
`checks.x86_64-linux.lanzaboote-vdeploy-vm-muninn` (`features/nixos/boot/test-vdeploy-muninn.nix`,
muninn's gate: the real `vdeploy apply` with `createKeys`, STIG test-host, `/etc` overlay),
`checks.x86_64-linux.lanzaboote-vdeploy-vm` (`features/nixos/boot/test-vdeploy.nix`, the
real `vdeploy apply` on drakkar's layout, keys by hand, including the missing-keys case) and
`checks.x86_64-linux.lanzaboote-vm` (`features/nixos/boot/test.nix`, the comin path). All
switch in, reboot into the lanzaboote generation, roll back, and reboot.

**What vdeploy does when the keys are missing** (proven by `lanzaboote-vdeploy-vm`): `lzbt`
fails in step 4 (`Failed to read public key from /var/lib/sbctl/keys/db/db.pem`), and
vdeploy still records `result: switched`, exits 0, and only says so in its note:
`healthy and running, but the boot entry was not written: …switch-to-configuration boot
failed`. X is running and is the `system` profile's newest generation; it is **not** marked
bad; the ESP and `loader.conf` are untouched, so a reboot boots the previous generation
through systemd-boot. Re-running vdeploy for the same X after creating the keys is
`already`: **vdeploy does not retry the boot step.** To recover, either reboot (the host
comes back on the previous generation, and the next apply of X does the whole transaction,
writing the UKIs), or have root run `/nix/var/nix/profiles/system/bin/switch-to-configuration boot`.
Watch `last.json`'s `note`, not its `result`.

The order matters. Both deployers apply every merge on their own, and `lzbt` fails if the
keys are missing. So **step 1 happens before the enable merges**, either by hand or, on a
host with `createKeys`, by the configuration itself.

### Keys created by the host: `features.hardening.secureBoot.createKeys` (GH-343)

muninn sets it; drakkar does not (yet). With it on, steps 1 and 2 below are done by the
configuration, with no new key material beyond the Secure Boot keys and no passphrase:

- **Keys.** `sbctl-ensure-keys` runs in the install hook, before `lzbt` signs (a systemd
  unit would be too late: `switch-to-configuration` installs the bootloader before it
  activates), and again from `sbctl-keys.service`. It runs
  `sbctl create-keys --database-path /var/lib/sbctl/GUID --export /var/lib/sbctl/keys` only when
  `keys/db/db.key` is missing, keeps the bundle root-only (0700), and **never overwrites**:
  a `keys/` without `db.key` is refused with an error, not replaced.
- **Encrypted backup.** `sbctl-keys.service` then writes, when it is missing,
  `/var/lib/sbctl-backup/sbctl-<host>.tar.age`: `tar` of `/var/lib/sbctl` piped to
  `age -R` with every operator ssh-ed25519 key in `common/fleet.nix` as a recipient. It is
  owned by the operator (`tom`, 0400), so it can be copied off the host without root. The
  keys never change, so the backup is written once; removed by hand, it is rewritten from
  the same keys at the next start of the unit.
- **Off-host copies** (unprivileged, from drakkar, after the first switch):
  `mkdir -p ~/backups/sbctl && scp tom@muninn:/var/lib/sbctl-backup/sbctl-muninn.tar.age ~/backups/sbctl/`,
  and a second copy onto mimir's `/data`, which drakkar mounts over NFS at `/mnt/mimir`
  (tom is in group `data`):
  `mkdir -p /mnt/mimir/backups/sbctl && cp ~/backups/sbctl/sbctl-muninn.tar.age /mnt/mimir/backups/sbctl/`.
  A file write only: nothing on mimir is restarted or reconfigured, and no root anywhere.
- **Recovery**, on the host, with any operator key (one command):
  `age -d -i ~/.ssh/id_ed25519 sbctl-<host>.tar.age | sudo tar -C /var/lib -xf -`
  This restores `/var/lib/sbctl` (keys, GUID) exactly; check with
  `sudo test -s /var/lib/sbctl/keys/db/db.key`. To inspect without restoring:
  `age -d -i ~/.ssh/id_ed25519 sbctl-<host>.tar.age | tar -tf -`.
- **Not automated:** enrollment. lanzaboote's `autoEnrollKeys` stays off. It only acts
  when the firmware is in Setup Mode (muninn, a Dell XPS 15 9500 on UEFI 2.70, reports
  `Secure Boot: disabled`, not in Setup Mode), and it would force-enroll at the next boot
  with nobody watching. Enrollment stays step 5, by hand, at the machine.

Under vdeploy (muninn), `sbctl-keys.service` is new in the generation, so the `test` step
starts it and it creates the keys; the hook in the `boot` step finds them and `lzbt` signs.
Both take one lock, so they never race. `checks.x86_64-linux.lanzaboote-vdeploy-vm-muninn`
asserts that order from the journal (the keys before `Installing Lanzaboote`), a rerun that
changes nothing, and the backup decrypting with an operator key. `lanzaboote-vm` covers the
comin path (keys from the hook on the first `switch`) and the refusal of a partial bundle.

1. **Keys, on the host, before the enable.** Run
   `sudo nix run nixpkgs#sbctl -- create-keys`. This writes `/var/lib/sbctl/keys/{PK,KEK,db}`
   and `/var/lib/sbctl/GUID`, which is `pkiBundle`. Check that
   `sudo test -s /var/lib/sbctl/keys/db/db.key` passes.
2. **Back up `/var/lib/sbctl` right away, off the machine.** For example:
   `sudo tar -C /var/lib -cf - sbctl | gpg -c > sbctl-<host>.tar.gpg`, stored on encrypted
   offline media or in the password manager. Never commit it. Before enrollment (step 5), a
   lost bundle only means creating keys again. After enrollment, losing `db.key` means no
   new generation can be signed until new keys are enrolled at the machine.
3. **Enable.** Set `features.hardening.secureBoot.enable = true` for the host, and merge.
   vdeploy switches the host (muninn, drakkar), and `lzbt` installs signed UKIs for every
   generation it keeps. Then check: `sudo sbctl verify` lists
   `/boot/EFI/Linux/nixos-generation-*.efi` as signed, and `/boot/loader/loader.conf` has
   `default nixos-generation-<N>-….efi`, where N is the `system` profile's newest
   (`readlink /nix/var/nix/profiles/system`; on a comin host, comin's newest,
   `readlink /nix/var/nix/profiles/system-profiles/comin`). Also read
   `/var/lib/vdeploy/last.json`: its `note` must be `now the system profile's newest
   generation and the boot default`, not `the boot entry was not written`.
4. **First reboot, at the machine.**
   - Remove the Python installer's entries:
     `sudo rm -f /boot/loader/entries/nixos-*.conf` (it names them by content hash,
     `nixos-<sha256>.conf`). `lzbt` does not remove them,
     they are unsigned, and once lanzaboote owns `EFI/nixos/` their kernels are not
     guaranteed to stay there.
   - Reboot. `bootctl status` should show `Current Entry: nixos-generation-<N>-….efi`, and
     `readlink -f /run/booted-system` should be the generation the deployer switched to.
   - If that entry fails to boot, pick an older lanzaboote generation in the systemd-boot
     menu. `lzbt` installs every kept generation, not just the new one.
5. **Enroll, at the machine.** Put the firmware in Setup Mode, run
   `sudo sbctl enroll-keys --microsoft` (keep the Microsoft keys, which the GPU option ROMs
   need), reboot, and turn Secure Boot on in the firmware. `bootctl status` should show
   `Secure Boot: enabled (user)`.
6. **Fallback while enrolled:** turn Secure Boot off in the firmware. The signed UKIs still
   boot with it off.

### Rollback to systemd-boot

1. If Secure Boot is on in the firmware, **turn it off first**. The Python installer's
   systemd-boot and kernels are unsigned, so an enforcing firmware refuses them.
2. Revert the enable (`features.hardening.secureBoot.enable` back to off) and merge. The
   deployer (vdeploy on muninn and drakkar) switches to a new generation with the
   Python installer. That installer writes
   `/boot/loader/entries/nixos-<sha256>.conf` for every generation and removes
   lanzaboote's files from `/boot/EFI/nixos/`. It does not touch `/boot/EFI/Linux/`.
3. **ESP cleanup:** `sudo rm -f /boot/EFI/Linux/nixos-generation-*.efi`. Those UKIs now point
   at kernels that step 2 deleted, and systemd-boot would still list them.
4. Reboot at the machine. `bootctl status` should show a `nixos-<sha256>.conf` current entry.
5. Keep the `/var/lib/sbctl` backup. Keys enrolled in firmware stay there until the firmware
   is reset to Setup Mode or its default keys.

## Runbook: TPM2 unlock

Do this after Secure Boot, because binding to PCR 7 only means something then.

1. Set `features.hardening.tpm2Unlock.enable = true` and deploy. Until enrollment it only
   adds a short TPM attempt before the usual passphrase prompt.
2. At the machine: `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-ssd-luks`
   (huginn/muninn: their own root partition label). The passphrase slot stays as the
   fallback.
3. Firmware or Secure Boot key changes invalidate the binding. Re-run step 2 with
   `--wipe-slot=tpm2`.

## Runbook: encrypt drakkar `/data` (destructive)

1. Back up `/data` in full and verify the backup.
2. `cryptsetup luksFormat /dev/disk/by-partlabel/disk-hdd-data`, using the cryptroot
   passphrase (the systemd initrd tries a cached passphrase on every LUKS device, so it is
   still one prompt). Then `cryptsetup open … cryptdata`, `mkfs.btrfs /dev/mapper/cryptdata`.
3. Change `hosts/drakkar/disko.nix` to wrap the data btrfs in `type = "luks"; name = "cryptdata";`
   in the **same** commit that is deployed right after the format. Restore the data.

Mimir's RAID5 needs one LUKS container per member and the array rebuilt over
`/dev/mapper/*`, which means a full 55 TB backup and restore. It is recorded as a gap, not
scheduled.

## Consequences

- On the next deploy every host's root password gets locked (reversible). Security sysctls
  apply for the first time, and the protocol modules stop autoloading.
- `features.hardening.*` is a new option namespace across `features/nixos/{users,boot}`. It
  doesn't collide with `features.keepalived` or the planned `features.<path>.enable` catalog,
  because no feature lives at `features/hardening`.
- The interactive hosts still report STIG profile `none` until the fleet-baseline import lands.
