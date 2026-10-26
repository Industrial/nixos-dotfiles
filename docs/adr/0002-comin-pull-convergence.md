# ADR-0002: Pull-based convergence with comin alongside deploy-rs

**Status:** Accepted
**Date:** 2026-10-26
**Supersedes:** clause 3 of [ADR-0001](./0001-fleet-deploy-rs.md) ("Disable comin on all hosts while push-deploy is primary")

## Context

ADR-0001 made deploy-rs the only activator and disabled comin to remove the
"generation race (comin + deploy)" from the threat model. Push-only deploy has
a failure mode that ADR-0001 did not weigh: **a host that is not reachable at
push time never converges at all, and nothing reports that it hasn't.**

Observed on 2026-10-26, with no alert having fired at any point:

| Host | State |
|------|-------|
| huginn | offline 23 days; last activated generation 23 days stale |
| mimir | offline 35 days |
| muninn | healthy, but joined to the *wrong tailnet* (personal, not `industrial.github`) and 10 days stale |

Compounding it, the fleet's two Prometheus/Grafana servers are mimir and
muninn — precisely the hosts that were down or misnetworked — and there is no
Alertmanager. Push-deploy silently degrades to "whatever was reachable the last
time an operator remembered", which is the condition config management exists
to prevent.

## Decision

1. **Re-enable comin** fleet-wide as `features/fleet/comin.nix`, imported
   explicitly per host (not folded into `remote-access.nix`, so that enabling
   convergence stays a visible, per-host decision).
2. **deploy-rs remains the operator's tool** for immediate and staged
   activation; comin is the unattended floor, not a replacement.
3. **origin/main is the only convergence source.** comin runs
   `operation = "switch"` on `main` at a 300s poll.
4. **Resolve the race by ordering, not by disabling either activator.**
   The operator commits and pushes before `bin/fleet deploy`. A push-deploy
   from a dirty or unpushed tree is *expected* to be reverted at the next poll
   — that is comin working correctly, not a defect.
5. **`testing-<hostname>` is the experiment path.** comin applies that branch
   with `switch-to-configuration test`: never written to the bootloader, so a
   bad experiment cannot survive a reboot or strand a host.
6. **Convergence is exported**, not assumed: comin's Prometheus exporter on
   `:4243` publishes per-host up-to-date status for the fleet Prometheus.

## Consequences

### Positive

- An offline host self-heals on next boot without operator action — the
  specific failure that produced a 35-day-stale host.
- Convergence becomes measurable (`:4243`), which is the precondition for
  alerting on drift instead of discovering it by hand.
- `testing-<hostname>` gives a bounded way to try a change on one host.

### Negative

- Reintroduces the dual-activator race ADR-0001 removed. It is contained by
  ordering discipline (decision 4), not eliminated. An operator who deploys a
  dirty tree and walks away will have their change reverted within 5 minutes.
- comin is not in nixpkgs; it adds a flake input (`github:nlewo/comin`) and so
  a third-party update surface on the activation path.
- Each host fetches the repository every 300s.

### Residual gap (not closed by this ADR)

Comin only begins converging a host *after* one push-deploy installs it. huginn
and mimir are offline and therefore still require a single manual
`bin/fleet deploy` when they next come up; convergence is automatic only from
that point on. There is still **no Alertmanager**, so drift is now observable
but not yet alerting — tracked as follow-up.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Keep push-only, add a staleness alert | Alerting on drift without fixing it still requires an operator to be present and awake; does not address the offline host |
| `system.autoUpgrade` timer | Converges to a flake ref, not to a reviewed branch state; no per-host testing path; no metrics |
| comin as the only activator | Loses immediate activation and `--dry-activate`, both load-bearing for risky changes with local-console-only recovery |
| Fold comin into `remote-access.nix` | Hides a change in activation semantics inside an access module, and would route around the assay that asserts that module does not enable comin |
