# ID Lanes

Map Maestro intake (`tiny` | `normal` | `high-risk`→`heavy`) to mode skips.

| Lane | Path | Skips |
|------|------|-------|
| **tiny** | ORIENT → (brief RESEARCH if unclear) → EXECUTE → REVIEW → SHIP | Full PLAN / Maestro mission when ask is unambiguous and blast radius ≤1 file/module |
| **normal** | Full pipeline; light Maestro task (`maestro_task_from_spec` or inline AC) | Heavy mission / multi-wave |
| **heavy** | Full pipeline + `/plan-hierarchically` + mission + execution overlay | Nothing — human approve before EXECUTE mandatory |

## How to set lane

1. During ORIENT, run `devenv shell -- maestro intake --paths <touched>` when paths known.
2. Else estimate: one-liner fix → `tiny`; single PR feature → `normal`; multi-PR / migrations / public API → `heavy`.
3. State `lane:<…>` every response. Upgrade lane if blast radius grows; never downgrade past human approval without saying so.

## tiny EXECUTE entry

Only enter EXECUTE from ORIENT/RESEARCH on `tiny` when:

- [ ] Sharp ask restated in one sentence
- [ ] Files to touch named
- [ ] No Maestro heavy mission required
- [ ] User did not demand a plan first
