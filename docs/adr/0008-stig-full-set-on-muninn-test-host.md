# ADR-0008: muninn is the STIG test host and accounts for all 103 controls

**Status:** Accepted
**Date:** 2026-11-27
**Issue:** #349 (owner decision 2026-11-26)
**Amends:** ADR-0004, decision 3, for muninn only. ADR-0004 said drakkar, huginn and muninn
carry no control modules. muninn now carries a profile of its own. mimir, drakkar and huginn
are unchanged, and so are ADR-0004's reasons for them.

## Context

ADR-0004 put the 68-control `base-safe` profile on mimir alone. The other 35 controls existed
only in `profiles/full.nix`, which no host enables, so nothing in the fleet had ever applied
them to a real machine. muninn's report read `1/103` against profile `none`.

The owner decided that one host should account for the whole benchmark, and chose muninn, the
work laptop. "Account for" means that each of the 103 controls is in exactly one of three
states on that host: configured, covered by external evidence, or excluded with a written
reason. No row of its report may read `Not Implemented`.

`full` cannot be that profile on a laptop. It carries controls that would take the machine off
its only network uplink, replace the operator's password, or fail to build without a log
collector, a PKI and a mail address that the fleet does not have.

## Decision

1. **A new profile, `features/security/stig/profiles/test-host.nix`**, registered in
   `features/catalog.nix` and enabled in `hosts/muninn/configuration.nix` only. It reports
   itself as `security.stig.profile = "test-host"`.
2. **It carries `base-safe` by import**, not by a second copy of the list, **plus 15 controls
   from the `full` set**: `V-268082`, `V-268083`, `V-268084`, `V-268086`, `V-268101`,
   `V-268102`, `V-268132`, `V-268133`, `V-268134`, `V-268135`, `V-268136`, `V-268152`,
   `V-268155`, `V-268172`, `V-268174`. That is 83 configured.
3. **It excludes 19 controls, each with a reason in `security.stig.exclude`.** Three are the
   benchmark's procedural controls (`V-268079`, `V-268125`, `V-268180`); their text is now in
   `features/security/stig/lib/procedural-exclusions.nix` and shared with `full`. Two are
   controls whose module does not enforce the requirement (decision 4). The other 14 are
   decisions about this machine:

   | Control | Why it is not applied on muninn |
   |---|---|
   | `V-268146` (CAT I) | The fix turns WiFi off, and WiFi is the laptop's only uplink |
   | `V-268147` | Bluetooth is on deliberately; waits for the owner's ruling |
   | `V-268168` (CAT I) | NixOS has no FIPS-validated module, and `fips=1` risks the LUKS root; revisit with VM evidence |
   | `V-268149` | The USNO time servers are not reachable from this network |
   | `V-268108`, `V-268109` | The fleet has no remote log collector |
   | `V-268124`, `V-268178` | No directory service, no PKI, no SSSD |
   | `V-268177`, `V-268179` | No PKCS#11 token is issued to the operator |
   | `V-268153` | No mail transport to send AIDE reports through |
   | `V-268139` | usbguard needs a policy generated at the laptop; waits for the owner |
   | `V-268138` | The operator's password hash is not in Nix yet (#340, #341) |
   | `V-268158` | The 1 MB/s SSH limit would refuse the fleet's own store-path traffic |

   The full text an assessor reads is in the profile, not here.
4. **A control whose module renders but does not enforce is excluded, not carried.**
   `V-268081` and `V-268170` were in the first cut of the 17 controls to configure. Evaluated
   on muninn, both modules produce a PAM line that has no effect (see below). A control that
   is present and not in effect must not be reported as compliant, and an untested PAM line
   does not go into the login, sshd, passwd or sudo stacks of a real laptop. Both are
   excluded, their modules are not imported on muninn, and each returns once its module is
   reworked and has a VM test.
5. **`V-268144` stays credited from `profiles/external-evidence.nix`**, as on every host.
   83 + 19 + 1 = 103.
6. **mimir stays on `base-safe`. drakkar and huginn stay on `none`.** Their evaluated systems
   do not change.
7. **`fleet-baseline` (ADR-0007) stays unwired.** That profile is meant for all interactive
   hosts and is switched on in `profiles/base.nix`, which would change drakkar and huginn.
   This decision is about one host. muninn does not need it either: every `fleet-baseline`
   control is also in `base-safe`.

## Consequences

- muninn's report reads `82/103` with no `Not Implemented` row: 74 compliant by
  configuration, 7 by VM test, 1 by external evidence, 2 configured and pending a reboot
  (`V-268092`, `V-268093`), 19 not applicable.
- **The pwquality.conf settings are written but not enforced on muninn.** `V-268126` to
  `V-268129`, `V-268134`, `V-268145` and `V-268169` render `/etc/security/pwquality.conf`
  and report compliant, as they do on mimir. Nothing in PAM reads that file until `V-268170`
  returns. The `V-268170` exclusion says so in the report.
- **muninn needs a reboot** for `audit=1` and `audit_backlog_limit=65536`, as mimir did.
- **Two CAT I controls are excluded on muninn** (`V-268146`, `V-268168`). `bin/ci/stig` treats
  `Not Applicable` on a CAT I control as a documented decision and passes. The owner made
  that decision for this host; it is recorded here because the runbook asks for an explicit
  ruling before a CAT I control is excluded.
- muninn takes on the audit set that ADR-0004 took off the interactive hosts. That cost is
  accepted for the test host.
- What changes for the operator on muninn: a consent banner on console, SSH and GDM logins; a
  session lock after 10 minutes idle; SSH ciphers and MACs narrowed to the STIG lists;
  SHA-512 for new password hashes. The operator's passwordless sudo rule
  (`features/fleet/operator-ssh.nix`) is unchanged, and `hosts/muninn/configuration.assay.nix`
  asserts it, along with WiFi, Bluetooth and mutable users staying as they are, and the
  login, sshd, passwd, chpasswd and sudo PAM stacks carrying no faillock or pwquality line.
- The fleet now has three postures: `test-host` on muninn, `base-safe` on mimir, `none` on
  drakkar and huginn.

## What applying the controls to a real host found

None of the 17 controls first chosen has a VM test, and until now they had only been read as
attribute sets by their own suites. Evaluating them inside a full NixOS configuration showed:

- **`V-268083` did not evaluate.** It set `services.openssh.banner`, which nixpkgs has
  removed. It now writes `/etc/ssh/banner` and sets `services.openssh.settings.Banner`.
- **`V-268174` did not evaluate.** Its definition of `/etc/default/useradd` conflicted with
  the one in nixpkgs. It now forces the file and restates the three lines nixpkgs writes.
- **`V-268155` was present and not in effect.** `features/nixos/security/sudo` sets
  `timestamp_timeout=-1` in the same option, and the last `Defaults` wins in sudoers. The
  control is now ordered after it.
- **`V-268170` renders and does not enforce.** `pam_pwquality` is placed after
  `password sufficient pam_unix.so` in the `passwd`, `chpasswd` and `sudo` stacks (order
  11000 against 10200), so a successful `pam_unix` ends the stack and `pam_pwquality` is
  never reached.
- **`V-268081` renders and does not enforce.** The `login` and `sshd` stacks get one
  `pam_faillock.so` line with no `preauth`, `authfail` or `authsucc` argument. In linux-pam
  1.7.2 the default action is the preauth one, which checks the tally and never writes it,
  so no failed attempt is recorded and no account is locked. GDM logins go through the same
  line, because `gdm-password` uses `login` as a substack.

The first three are fixed in their own commits. The last two are not: reworking a PAM stack
needs a VM test before it reaches a real host, and this change adds none. They are excluded
under decision 4, and with their modules not imported the rendered login, sshd, passwd,
chpasswd and sudo files on muninn differ from before only by what `base-safe` brings (the
`limits.conf` that carries `maxlogins`, `V-268085`).

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Enable `full` on muninn | It does not build without a log collector, a PKI, an SSSD configuration and a mail address, and the controls that do build would take the laptop off its network and replace the operator's password. |
| Leave the 14 as `Not Implemented` | The report would give no reason for them, and the reason is what an assessor asks for. |
| Put the 17 controls into `base-safe` | That changes mimir, which this decision leaves alone. |
| Wire `fleet-baseline` in the same change | It changes drakkar and huginn. Out of scope here. |

## Verification

Run on 2026-11-27, before the commits:

```bash
assay run features/security/stig    # passes
assay run hosts                     # passes
nix build .#stigReport.muninn       # muninn: 82/103, 0 Not Implemented
nix build .#nixosConfigurations.muninn.config.system.build.toplevel
```

The system derivations of mimir, drakkar and huginn were compared against `origin/main` with
`system.configurationRevision` held constant, since that value is the git revision and
differs between any two commits. All three were identical.
