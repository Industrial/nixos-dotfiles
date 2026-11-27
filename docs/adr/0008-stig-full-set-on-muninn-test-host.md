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
2. **It carries `base-safe` by import**, not by a second copy of the list, **plus 16 controls
   from the `full` set**: `V-268081`, `V-268082`, `V-268083`, `V-268084`, `V-268086`,
   `V-268101`, `V-268102`, `V-268133`, `V-268134`, `V-268135`, `V-268136`, `V-268152`,
   `V-268155`, `V-268170`, `V-268172`, `V-268174`. That is 84 configured.
   (15 and 83 when this was first accepted. `V-268081` and `V-268170` joined and `V-268132`
   left, all three under decision 4; see the amendments below.)
3. **It excludes 18 controls, each with a reason in `security.stig.exclude`.** Three are the
   benchmark's procedural controls (`V-268079`, `V-268125`, `V-268180`); their text is now in
   `features/security/stig/lib/procedural-exclusions.nix` and shared with `full`. One,
   `V-268132`, is a control whose module does not enforce the requirement (decision 4). The
   other 14 are decisions about this machine:

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
4. **A control whose module renders but does not enforce is excluded, not carried.** A
   control that is present and not in effect must not be reported as compliant, and an
   untested PAM line does not go into the login, sshd, passwd or sudo stacks of a real
   laptop. Such a control is excluded, its module is not imported on muninn, and it returns
   once its module is reworked and has a VM test of what it enforces.

   This rule was written for `V-268081` and `V-268170`, which were in the first cut of the 17
   controls to configure and whose modules produced a PAM line with no effect (see below).
   Both were excluded under it. Both now meet it and are carried: see the first amendment
   below. The rule stays, and has been applied once more: `V-268132` was carried, was found
   to enforce nothing, and is excluded (second amendment).
5. **`V-268144` stays credited from `profiles/external-evidence.nix`**, as on every host.
   84 + 18 + 1 = 103.
6. **mimir stays on `base-safe`. drakkar and huginn stay on `none`.** Their evaluated systems
   do not change.
7. **`fleet-baseline` (ADR-0007) stays unwired.** That profile is meant for all interactive
   hosts and is switched on in `profiles/base.nix`, which would change drakkar and huginn.
   This decision is about one host. muninn does not need it either: every `fleet-baseline`
   control is also in `base-safe`.

## Consequences

- muninn's report reads `83/103` with no `Not Implemented` row: 75 compliant by
  configuration, 7 by VM test, 1 by external evidence, 2 configured and pending a reboot
  (`V-268092`, `V-268093`), 18 not applicable. (`82/103`, 74 and 19 before the amendments.)
- **There is no minimum password age on muninn**, and the report says so: `V-268132` is
  `Not Applicable` with the reason, where it used to read compliant on the strength of a
  line in `login.defs`.
- **The pwquality.conf settings are enforced on muninn, for users.** `V-268126` to
  `V-268129`, `V-268134`, `V-268145` and `V-268169` render `/etc/security/pwquality.conf`,
  and with `V-268170` carried, `passwd` refuses a password that fails them. Two limits come
  from the benchmark and are pinned by the VM test: root is warned and not refused
  (`enforce_for_root` is in no control), and a password changed because it expired goes
  through the `login` password stack, which the check does not name. On mimir, which stays
  on `base-safe`, the file is still written and nothing in PAM reads it.
- **Three wrong passwords lock an account on muninn until an administrator releases it**
  (`V-268081`, `unlock_time=0`). That covers the console, the GDM greeter and the lock
  screen, which share one tally. It does not cover SSH: sshd there takes keys only, and a
  key logon is neither refused by a lock nor clears it. The way back in for a locked
  operator is SSH with a key and `sudo faillock --user <name> --reset` (the operator's sudo
  rule needs no password); failing that, a reboot, since the tally is in `/run/faillock`.
  Root's password is locked on this host, so the root console is not a way back in.
- **muninn needs a reboot** for `audit=1` and `audit_backlog_limit=65536`, as mimir did.
- **Two CAT I controls are excluded on muninn** (`V-268146`, `V-268168`). `bin/ci/stig` treats
  `Not Applicable` on a CAT I control as a documented decision and passes. The owner made
  that decision for this host; it is recorded here because the runbook asks for an explicit
  ruling before a CAT I control is excluded.
- muninn takes on the audit set that ADR-0004 took off the interactive hosts. That cost is
  accepted for the test host.
- What changes for the operator on muninn: a consent banner on console, SSH and GDM logins; a
  session lock after 10 minutes idle; SSH ciphers and MACs narrowed to the STIG lists;
  SHA-512 for new password hashes; the three-strike lock; and a new password has to be 15
  characters with all four classes and no dictionary word. The operator's passwordless sudo
  rule (`features/fleet/operator-ssh.nix`) is unchanged, and
  `hosts/muninn/configuration.assay.nix` asserts it, along with WiFi, Bluetooth and mutable
  users staying as they are, and the enforcing lines of the login, sshd, passwd, chpasswd
  and sudo PAM stacks, in the order that makes them enforce.
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

The first three are fixed in their own commits. The last two were not fixed in that change:
reworking a PAM stack needs a VM test before it reaches a real host, and that change added
none. They were excluded under decision 4, and with their modules not imported the rendered
login, sshd, passwd, chpasswd and sudo files on muninn differed from before only by what
`base-safe` brings (the `limits.conf` that carries `maxlogins`, `V-268085`).

## Amendment 2: `V-268132` excluded, `V-268086` corrected

**Date:** 2026-11-27, same issue (#349). Both were found by the VM tests written for the 15
controls, which is what those tests were for.

**`V-268132` (one-day minimum password lifetime) is excluded under decision 4.** The fix
text sets `PASS_MIN_DAYS 1` in `/etc/login.defs`, and the published check greps that file and
passes. Nothing enforces it. Observed on the pinned system, and pinned by
`checks.x86_64-linux.stig-V-268132`:

- shadow 4.20.3 no longer implements a minimum age. `useradd` leaves the field empty for a
  new account; `chage` has no `--mindays`, `passwd` has no `-n`, and `chage -l` does not
  report one. The `login.defs` manual no longer documents the key.
- NixOS has no option that sets the field for a declared user. Its user activation script
  carries an existing value over and never writes one.
- Written into `/etc/shadow` by hand, the field is honoured by pam_unix: a second change on
  the same day prints "You must wait longer to change your password" and the stored hash
  does not change. `passwd` then prints "password updated successfully" and exits 0, because
  nixpkgs renders pam_unix as `sufficient` in the password stack and its refusal is dropped.

So the only way to enforce the control here is to edit `/etc/shadow` on every activation,
against a feature shadow has removed, and the result tells the user a refused change
succeeded. That is not applied to a real laptop. The control module is unchanged and stays
in `full`. It returns to muninn when one of the pinned observations changes.

**`V-268086` (10-minute idle lock) locked nothing in dconf.** The control set
`idle-delay` to 600 and declared the lock as `org/gnome/desktop/session/idle-delay`, without
the leading slash a dconf lock path needs. dconf ignores such a line, so the key read 600 and
a user could set it to 0. The path is corrected, and `stig-V-268086` now asserts that
`dconf list-locks` shows the key and that a user's own write is refused. The setting itself
was already applied: on muninn the control's database is first in the user profile and no
other database sets that key.

## Amendment 1: `V-268081` and `V-268170` reworked and carried

**Date:** 2026-11-27, same issue (#349). Decision 4 is unchanged; these two controls now
meet it.

**`V-268081`.** The module builds the stack of pam_faillock(8)'s second example out of
nixpkgs' structured rules, around nixpkgs' own `sufficient` pam_unix:

```
auth    required      pam_faillock.so preauth audit deny=3 fail_interval=900 silent unlock_time=0
auth    sufficient    pam_unix.so ...            (nixpkgs' rule, untouched)
auth    [default=die] pam_faillock.so authfail audit deny=3 fail_interval=900 unlock_time=0
account required      pam_faillock.so
```

It differs from the published fix text in three ways, each deliberate. There is no
`authsucc` line: behind a `sufficient` pam_unix it can never run, and the account line does
the reset. There is no `even_deny_root` and no `dir=`, which are in the check's sample line
and not in the fix text: root is never locked, and a reboot clears the tally. The orders
are relative to pam_unix's, and an assertion refuses a build in which preauth is not ahead
of it.

**SSH keys and a locked account.** A key logon is not blocked by the lock and does not clear
it. sshd does not run the auth stack for a key, so preauth never sees the logon; and
linux-pam 1.7.2's account-phase call skips its reset when the auth stack has not run in the
same transaction (pam_faillock(8), NOTES). The requirement counts invalid logon attempts,
and a key logon is not one. The benchmark's text does not ask for more. This is also what
keeps the operator able to reach a locked laptop.

**`V-268170`.** `pam_pwquality` is ordered directly ahead of pam_unix in the `passwd`,
`chpasswd` and `sudo` password stacks, and pam_unix gets `use_authtok`, so it stores the
password that was checked.

**The tests that decision 4 asks for.** Each asserts what the machine refuses, not what
`/etc/pam.d` contains:

- `checks.x86_64-linux.stig-V-268081`: at a real console, two failures and a success leave
  no tally; three failures lock the account and the correct password is refused; another
  user is unaffected; a key logon over SSH succeeds and leaves the tally as it was; root
  releases the account with `faillock --reset`.
- `checks.x86_64-linux.stig-V-268170`: `passwd` as a user refuses a short password, one with
  a single character class, one with no special character and a dictionary word with a digit
  and a symbol appended, leaving the stored hash unchanged each time; it accepts a compliant
  one; `chpasswd` as root is warned and not refused; sudo still authenticates.
- `checks.x86_64-linux.stig-test-host-logon`: the same on muninn's own configuration, where
  the stack has an early pam_unix and gnome-keyring in it and the graphical logon reaches it
  as a substack. The operator's password is accepted; three wrong ones through
  `gdm-password` lock the account there and at the console; the operator logs in over SSH
  with a key, runs `sudo -n faillock --reset`, and is accepted again.

Both `stig-V-*` tests were run once against the previous module text with their file-reading
assertions removed, and failed on behaviour: no failure was ever recorded, and `passwd` took
an 8-character password.

**Not covered.** No test types into the GDM greeter itself; `gdm-password` is exercised
through `pamtester`, which runs the same PAM service. The switch from the generation muninn
runs today to this one was not rehearsed against that exact generation;
`etc-overlay-live-switch-muninn` switches the new configuration in and out live.

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
