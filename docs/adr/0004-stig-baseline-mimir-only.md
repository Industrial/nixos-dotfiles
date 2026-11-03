# ADR-0004: The STIG baseline applies to mimir only, not fleet-wide

**Status:** Accepted
**Date:** 2026-11-03
**Supersedes:** the fleet-wide scope established by `10ff2670` (adopt the Anduril NixOS STIG
as the hardening baseline) and `1f75a7b6` (complete the STIG baseline). The baseline itself,
its control modules, its report and its CI gate are all unchanged — only *which hosts carry
it* changes.

## Context

`profiles/base.nix` imported `features/security/stig/profiles/base-safe.nix`, so all four
hosts carried 68 of the 103 Anduril NixOS STIG V1R3 controls. The profile's membership rule
was "no interactive cost": a control belongs in `base-safe` only if it changes no login,
lock, device, radio or password-entry behaviour a user would notice.

That rule turned out to be the wrong test. It is a test about *interaction*, and the audit
set passes it — auditd changes no prompt and no keystroke — while still being the most
expensive thing in the profile on a machine that is actually used:

- `V-268095` audits `rename`/`unlink`/`rmdir`/`renameat`/`unlinkat`
- `V-268098` audits the denied `open`/`creat`/`truncate` family
- `V-268099` audits the `chown` family, `V-268100` the `chmod` family
- `V-268094` audits `mount`, `V-268091` every privileged command execution

A Nix build, a `git` operation, a shader cache write and a game launch all generate records
through those rules, continuously, on the host doing the most of all four of those things.

The symptom reached the fleet before the cause was named. `6f5e7011` ("raise audit backlog
limit to 65536 to stop desktop stalls") raised `audit_backlog_limit` on every host because
drakkar was stalling. That change is correct as far as it goes and stays in the profile — but
it enlarges the queue the records sit in rather than questioning whether a workstation should
be generating them. drakkar is the desktop and the gaming station; it has no assessor, no
accreditation boundary and no audit reviewer. The records it was producing were never going
to be read.

Two further facts decided the scope:

1. **The "four desktops" framing was already load-bearing in the docs and wrong in the
   repo.** `huginn` and `muninn` are tablets and `mimir` is the file server, yet all four
   import `profiles/desktop.nix` and `profiles/development.nix`. There is no `profiles/server.nix`
   to hang a server-only baseline on. The honest partition is not desktop-vs-server but
   *has an interactive user* vs *does not*, and only mimir is on the right side of it.
2. **The report and the CI gate already model a host that carries nothing.** `security.stig`
   defaults to `enable = false` / `profile = "none"` / `implemented = []`, and
   `lib/report.nix` renders every control `Not Implemented` with the basis "This host's stig
   profile (none) does not carry the control." `bin/ci/stig` then treats a CAT I control at
   `Not Implemented` as a documented decision and only fails on CAT I controls in *other*
   non-compliant states. Narrowing the scope therefore needs no change to either.

## Decision

1. **`profiles/base.nix` imports `features/security/stig/default.nix`** — the option surface
   alone. It declares `security.stig.*` and configures nothing on its own: its two `config`
   stanzas are conditional on `pwquality` being non-empty and on `security.audit` already
   being enabled, neither of which holds without control modules.
2. **`hosts/mimir/configuration.nix` imports `profiles/base-safe.nix`** directly. Mimir is
   the only host carrying controls.
3. **drakkar, huginn and muninn carry no control modules** and score `1/103` against profile
   `none`. The single compliant control is `V-268144` (CAT I, confidentiality at rest),
   credited from the new `profiles/external-evidence.nix` — see decision 6. This is the
   reported posture, not a gap to close.
4. **`profiles/full.nix` remains VM-test-only** and is unchanged.
5. **No control module, VM test, report renderer or gate is modified.** The controls
   themselves, `lib/report.nix` and `bin/ci/stig` are untouched.
6. **Externally-satisfied controls move out of the profile** into
   `features/security/stig/profiles/external-evidence.nix`, imported by `profiles/base.nix`.
   `V-268144` was declared inside `base-safe.nix`, so narrowing that profile to mimir would
   have withdrawn a true CAT I claim from the other three hosts — their roots are LUKS
   containers exactly as mimir's is, and `hosts/<name>/disko.assay.nix` asserts it for all
   four. The evidence is a property of the fleet's disk layout, not of a baseline, so it is
   now declared once, independently of which profile a host carries.
   `profiles/full.assay.nix` reads that same file for its completeness proof, so the roster
   and the proof cannot disagree, and `external-evidence.assay.nix` asserts every id is in
   the manifest and every citation names a file.

The option surface must stay fleet-wide. `flake.nix` builds `stigReport.<host>` for all four
hosts from `nixosConfigurations.<host>.config.security.stig`; dropping `default.nix` from
`profiles/base.nix` would make `nix build .#stigReport.drakkar` fail to **evaluate** rather
than report an unhardened host, turning a finding into an error.

## Consequences

### Positive

- drakkar stops generating audit records nobody reads, on the host where the cost was
  observable.
- The compliance claim gets narrower and therefore truer. "The fleet is STIG-hardened" was
  always doing work the evidence did not support on three interactive machines; "mimir is"
  is checkable.
- Mimir keeps the full 68-control baseline, including the SSH crypto and password-quality
  controls, on the host that actually faces the network as a server.
- `bin/ci/stig` still fails on a CAT I regression on mimir — the gate did not weaken for the
  host that has the baseline.

### Negative

- **Three hosts lose real hardening, not only auditing.** Dropping the whole profile also
  drops `V-268078` (firewall), `V-268173` (AppArmor), `V-268089`/`V-268157`/`V-268159`
  (CAT I SSH crypto), `V-268137` (no root SSH login), `V-268160`/`V-268161` (sysctls), the
  six pwquality settings, `V-268130` (SHA-512), and `UMASK 077`. Several of those cost an
  interactive user nothing and were not the problem. This was the explicit instruction and
  is recorded as such rather than quietly narrowed to the audit set.
  - Partial mitigation already in place, verified by evaluation rather than assumed:
    `features/security/apparmor`, `features/nixos/networking/firewall.nix`,
    `features/nixos/security/sudo` and `features/nixos/security/no-defaults` are imported by
    `profiles/base.nix` independently of the STIG profile. On drakkar after this change,
    `networking.firewall.enable`, `security.apparmor.enable` and
    `security.sudo.wheelNeedsPassword` are all still `true` — so `V-268078`, `V-268173` and
    `V-268156` remain *satisfied in substance* on all four hosts even though the report no
    longer credits them. The pwquality settings and `UMASK 077` have no such backstop and are
    genuinely gone from the three hosts.
  - **The SSH crypto loss is conformance, not strength.** `V-268089` pins
    `Ciphers = [aes256-ctr aes192-ctr aes128-ctr]`. Dropping it returns drakkar to the
    nixpkgs default — `chacha20-poly1305@openssh.com`, `aes256-gcm`, `aes128-gcm`, then the
    three CTR ciphers — which is a *stronger* set by current practice, since the STIG list
    excludes the AEAD modes. The three hosts lose the ability to claim the control, not the
    confidentiality it exists to protect. The same reasoning applies to `V-268157` (MACs).
- The fleet now has two hardening postures to reason about instead of one.
- If the fleet is ever assessed as a whole, three hosts will report `1/103` and the answer is
  this ADR, not a remediation sprint.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Split the ~26 audit controls into `profiles/audit.nix`, servers only; keep the rest everywhere | Offered and declined. It is the narrower fix for the stated symptom and keeps CAT I SSH crypto on the tablets, but the instruction was the whole baseline. Recorded here because it remains the obvious way back. |
| Keep the baseline on huginn and muninn as well | They are tablets with interactive users and `profiles/desktop.nix`; the same audit cost applies, just on slower hardware. |
| Tune auditd instead — rate limits, `-F` exclusions, a smaller rule set | Every rule is a control. Weakening a rule makes the control claim false while still reporting it compliant, which is the failure mode the report exists to prevent. Dropping the control honestly is better than keeping a hollowed-out version of it. |
| Keep `audit_backlog_limit=65536` as the fix | That was `6f5e7011`, and the stalls were the reason this ADR exists. A bigger queue does not stop the records being generated. |
| Gate the profile behind an `enable` flag on each host | The feature is composed by import, not by flags — `features/security/stig/default.nix` says so explicitly, and so does every other feature in this repo. Adding a flag for one case would be a second pattern. |

## Verification

All run on 2026-11-03, before the commit:

```bash
assay run features/security/stig    # 593/593 passed (588 before, +5 external-evidence)
nix build .#stigReport.mimir        # mimir: 67/103 — unchanged from before this ADR
nix build .#stigReport.drakkar      # drakkar: 1/103, profile "none", evaluates cleanly
bin/ci/stig                         # OK — CAT I gate passes on all four hosts
```

Per-host evaluation of the thing that actually prompted this, confirming the audit subsystem
is off on the three interactive hosts and intact on mimir:

```
drakkar   profile=none       controls=0   audit.enable=false  kernelParams=[]
huginn    profile=none       controls=0   audit.enable=false  kernelParams=[]
mimir     profile=base-safe  controls=68  audit.enable=true   kernelParams=[audit=1,audit_backlog_limit=65536]
muninn    profile=none       controls=0   audit.enable=false  kernelParams=[]
```

Mimir needs a **reboot**, not just a switch, for `V-268092`/`V-268093` to take effect; until
then its report shows them as "Configured (pending reboot)" and it scores 67, not 69.
