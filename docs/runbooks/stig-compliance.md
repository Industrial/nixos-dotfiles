# Runbook: Anduril NixOS STIG compliance

The fleet carries the [Anduril NixOS STIG](https://cyber.trackr.live/stig/Anduril_NixOS/1/3)
V1R3 (103 controls, 11 CAT I / 91 CAT II / 1 CAT III) as its hardening baseline. It replaces
nixpkgs' `profiles/hardened.nix`, removed in 26.05 for lacking "a consistent and transparent
baseline or standard" — see [ADR-0003](../adr/0003-kernel-hardening-single-source.md).

**This benchmark ships no OVAL/SCAP content.** All 103 checks are manual
(`check-content-ref name="M"`), so no SCC or OpenSCAP run can grade a NixOS host against it.
Everything below exists because there is nothing off the shelf.

## Reading the report

```bash
nix build .#stigReport.muninn
cat result/report.md        # the assessor-facing table
jq . result/report.json     # same data, stable-sorted, for tooling
cat result/summary.txt       # one line: "muninn: 67/103 compliant"
```

Status is derived from the evaluated configuration, never hand-maintained. Six values, and
the distinctions matter:

| Status | Means | Counts as compliant |
|---|---|---|
| `Compliant (configuration)` | Provable by evaluating the config; a colocated suite asserts it | yes |
| `Compliant (VM test)` | Runtime-only state, proven on a booted machine | yes |
| `Compliant (external evidence)` | Met outside the STIG module set; the Basis column cites the evidence | yes |
| `Configured (pending reboot)` | Correct in the generation, not yet in effect on the running kernel | **no** |
| `Not Applicable` | Excluded, with a written justification | **no** |
| `Not Implemented` | In the benchmark, not carried by this host's profile | **no** |

`Configured (pending reboot)` is not pedantry. It exists because muninn reported findings for
`V-268092`/`V-268093` **after a successful comin switch**: `switch-to-configuration switch`
cannot change a running kernel's command line, so `/proc/cmdline` keeps the booted
generation's parameters while `/run/current-system/kernel-params` carries the new ones. A host
that will comply after a reboot does not comply now.

### Verifying a live host

The report describes what a host is *configured* to be. To check what it *is*:

```bash
ssh <host> 'sudo bash -s' < .tmp/verify-muninn.sh
```

That script runs the assessor-style commands directly. Use it after any change that touches
audit rules — the report cannot see a failed `audit-rules-nixos.service`.

## Profiles

| Profile | Controls | Where |
|---|---|---|
| `base-safe` | 68 — nothing a user would notice | `profiles/base.nix`, so every host |
| `full` | all 103 | VM test targets only, **never** a workstation |

Membership is decided by [`docs/security/stig-triage.md`](../security/stig-triage.md), and
`base-safe.assay.nix` parses that table and asserts the profile carries exactly the controls
classified `base`. A disruptive control cannot drift onto the four desktops.

## Adding a justified exclusion

Excluding a control is a decision, and the justification is the artifact an assessor reads.
Say *why*, not *that*:

```nix
security.stig.exclude = {
  "V-268079" = "No emergency or temporary accounts exist on this host. Must be re-asserted if one is created.";
};
```

Then drop the control's import from the profile. Both halves are required: an exclusion alone
leaves the control applied, and dropping the import alone makes the report say
`Not Implemented` with no reason.

**Excluding a CAT I control needs an explicit operator ruling.** `bin/ci/stig` fails the build
on any CAT I that is neither compliant nor documented, so this is not something that can be
done quietly.

## When a new STIG release lands

The upgrade path is deliberately a build failure.

1. Download the new `U_Anduril_NixOS_V1R<n>_STIG.zip` from
   <https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/>, extract `*-Manual-xccdf.xml`.
2. Add it as `features/security/stig/data/Anduril_NixOS_STIG-V1R<n>.xccdf.xml`; update
   `data/PROVENANCE.md` with the new sizes, hashes and verified properties.
3. Point `lib/parse-xccdf.nix` at the new file and run `bin/stig-xccdf-to-json`.
4. `nix eval` now **throws**: `lib/manifest.nix` lists the ids we acknowledge and no longer
   matches the parsed set. Work through the delta — a new control needs an entry, a control
   module, a colocated suite and a VM spec; a removed control needs all four deleted.
5. Re-check the banner wording. DISA changed it once already (DoD → DoW in V1R3), and an
   implementation pinned to the old text fails `V-268082`/`083`/`084` silently.

Do not regenerate `manifest.nix` mechanically to silence the throw. That defeats the only
mechanism standing between a release bump and undetected drift.

## Gates

| Gate | Runs | Catches |
|---|---|---|
| `moon run test` | every commit (prek) | control modules declare what their control requires |
| `bin/assay-coverage-check` | every commit | a `.nix` file with no colocated suite |
| `bin/ci/stig` | PR and main | report builds; **CAT I regression fails the build** |
| `moon run stig-vm-test` | main (`STIG_VM=1`) | 68 booted machines, one per control |

The VM tests are the only gate that proves the runtime half. They have already caught things
no amount of static analysis would:

- `auditctl` **aborts the entire rules file** on the first unloadable rule, so one bad watch
  left the host with *zero* audit rules while the configuration looked correct.
- `V-268116` names a group that does not exist (`systemd-journald` is the daemon; the group is
  `systemd-journal`), so the published `chown` fails outright.
- `V-268078`'s check requires `firewall-panic`, a binary nixpkgs **removed** in favour of
  `nixos-firewall-tool`.

## ⚠ The CI gate does not gate deployment

Be clear about what the gates do and do not do.

comin polls `origin/main` every 300s and activates whatever is there
([ADR-0002](../adr/0002-comin-pull-convergence.md)). GitHub Actions runs *after* the push, in
parallel. **comin does not wait for CI**, so `bin/ci/stig` is a detector, not a gate: a
compliance regression pushed to `main` reaches the hosts whether CI is green or not.

This was demonstrated the hard way. Commit `10ff2670` landed the baseline with an audit rule
set that failed to load; it sat on `main` for the interval before `29e34542` fixed it, and any
host coming online in that window would have converged to a configuration that reported itself
compliant while running unaudited.

Mitigations, in order of effort — **none is implemented, this is a standing decision**:

1. **Push to `testing-<hostname>` first.** comin applies that branch with
   `switch-to-configuration test`, never written to the bootloader, so it cannot strand a host
   across a reboot. Already supported; costs nothing but discipline.
2. **Have comin track a `deploy` branch** that CI fast-forwards from `main` only when green.
   This makes CI an actual gate. It changes how every host gets its config, so it needs an ADR
   and an operator decision, not an implementer's preference.
3. **Accept it** and rely on the detector plus fast rollback (`comin` keeps the previous
   generation; `nixos-rebuild --rollback` on the host).

## Open decisions

| Decision | Why it is yours |
|---|---|
| `V-268130` / `V-268175` — yescrypt vs SHA-512 | nixpkgs defaults `ENCRYPT_METHOD` to **YESCRYPT** (memory-hard); the control forces **SHA512**, a downgrade, and `V-268175` then flags existing `$y$` hashes. Excluding a CAT I control is an operator ruling. Exclusion text is drafted in `controls/V-268130.nix`. |
| The six PKI/MFA controls | `V-268124`, `125`, `135`, `136`, `177`, `179` all presuppose identity infrastructure this fleet lacks. `features/security/yubikey` is the only basis. Build toward them, or exclude as a group with one justification. |
| `V-268101` / `V-268102` notification target | Audit-volume alerts need a real SA/ISSO destination or they are decorative. |
| comin/CI ordering | See above. |
