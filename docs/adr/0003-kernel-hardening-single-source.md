# ADR-0003: The STIG baseline is the single source of kernel hardening

**Status:** Accepted
**Date:** 2026-10-28
**Context:** wave 1 of mission `pln-mvrbafkb-iw5tn6` (Anduril NixOS STIG baseline), leaf `leaf-resolve-kernel-orphan`

## Context

`features/security/kernel/` has existed in this repo as **dead code**. No profile, host,
feature or common module imported it:

```
$ grep -rn 'security/kernel' profiles hosts features common
features/fleet/remote-access.nix:5:    ../security/tailscale
```

— the only hit is an unrelated sibling. Its settings have therefore never been active on
drakkar, huginn, mimir or muninn. Its colocated suite passed the whole time, asserting the
values of an attrset nothing evaluated into a system.

Adopting the Anduril NixOS STIG forces the question, because the STIG also configures kernel
behaviour. Two sources of kernel hardening in one repo is the duplicate-source-of-truth
problem that silently diverges.

Three facts decided it:

1. **The STIG does not require any of the orphan's options.** Searching all 103 controls'
   fix and check text for `security.lockKernelModules`, `security.protectKernelImage`,
   `security.unprivilegedUsernsClone` and `security.kernelLockdown` returns **nothing**. The
   kernel-adjacent controls are `V-268092` and `V-268093` (`boot.kernelParams` for audit),
   `V-268141`, `V-268160`, `V-268161` (`boot.kernel.sysctl`), and `V-268168` (`fips=1`).
   There is no overlap at all.
2. **Two of the orphan's three security options are disruptive**, which is presumably why it
   was never imported: `security.protectKernelImage = true` blocks kexec and hibernation
   (huginn is a tablet), and `security.lockKernelModules = true` blocks module loading after
   boot, which breaks hot-plugged hardware and VM kernel modules.
3. **One of them is not hardening at all.** `security.unprivilegedUsernsClone = true`
   *enables* unprivileged user namespaces — the opposite of what nixpkgs'
   now-removed `profiles/hardened.nix` did with the same knob. Keeping it under a directory
   named "security" misrepresents what it does.

A fourth, unrelated setting rode along: `users.defaultUserShell = pkgs.bash`. This was the
repo's **only** assignment of that option, and it is a downgrade — nixpkgs already defaults to
`bashInteractive` (verified: `bash-interactive-5.3p20`), so an inactive module was the only
thing proposing non-interactive `bash` as the login shell.

## Decision

1. **Delete `features/security/kernel/` entirely** — `default.nix` and `default.assay.nix`.
2. **`features/security/stig/` is the only source of kernel hardening** in this repo going
   forward. Kernel settings arrive as STIG control modules with an id, a colocated suite and
   a VM test, or they do not arrive.
3. **The three dropped security options are not reintroduced as STIG controls**, because no
   control requires them. If any is wanted, it comes back as its own explicit, non-STIG
   decision with its disruption documented — not smuggled in under a compliance banner.
4. **`users.defaultUserShell` is left unset**, falling through to the nixpkgs default.

## Consequences

Nothing changes on any host. The deleted module was inert, so this is a removal of dead code
plus a statement of where kernel settings live. Concretely:

- `security.lockKernelModules`, `security.protectKernelImage` and
  `security.unprivilegedUsernsClone` return to their nixpkgs defaults — which is what every
  host has actually been running.
- The repo loses two `.nix` files and the two passing assertions in
  `features/security/kernel/default.assay.nix`. Those assertions were testing dead code.
- Kernel hardening becomes reviewable against an external standard instead of against taste.

## Note for wave 1: the STIG's kernel controls contain two traps

Found while confirming coverage; both belong in `lib/report.nix`'s justification column rather
than being quietly worked around.

**`V-268160` is mistitled.** The requirement reads "NixOS must implement nonexecutable data to
protect its memory from unauthorized code execution" — NX/DEP. The fix and check are entirely
about kernel pointer leakage:

```
$ sudo sysctl kernel.kptr_restrict
kernel.kptr_restrict = 1
If "kernel.kptr_restrict" does not have a value of "1" or is missing, this is a finding.
```

We implement what the check verifies, and record that the title does not describe it.

**Stricter is non-compliant.** The check fails on anything other than `1`, so
`kernel.kptr_restrict = 2` — the value the deleted module proposed in its commented-out
sysctl block, and the more restrictive setting — would be scored as a finding. Compliance here
is an equality test, not a floor. Do not "improve" these values.

## References

- [docs/security/stig-triage.md](../security/stig-triage.md) — all 103 controls classified
- `features/security/stig/data/PROVENANCE.md` — benchmark provenance and release procedure
- nixpkgs removed `nixos/modules/profiles/hardened.nix` in 26.05 for lacking "a consistent and
  transparent baseline or standard" ([PR #383438](https://github.com/NixOS/nixpkgs/pull/383438));
  this ADR is the local answer to that gap.
