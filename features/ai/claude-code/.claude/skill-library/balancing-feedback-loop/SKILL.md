---
name: balancing-feedback-loop
description: Identify and analyze balancing (stabilizing) feedback loops that counteract deviation from a goal or setpoint. Use for control systems, regulation, resistance to change, and equilibrium dynamics.
---

# Balancing Feedback Loop Analysis

## Goal

Detect **B-loops** that **oppose change** and pull a system toward a goal, setpoint, or equilibrium — explaining stability, resistance, and self-correction.

## When to Use

- System returns to baseline after disturbance
- Change initiatives face "rubber band" snapback
- Thermostat-like regulation (inventory, autoscaling, budgets)
- After **connection-circles** mapping

## When NOT to Use

- Runaway growth or collapse (**reinforcing-feedback-loop**)
- No observable goal or setpoint behavior
- Open-loop cause-effect only

## Identification Rule

Closed loop with **odd number of negative (−) links** → **Balancing (B)**.

Classic structure: gap between **goal** and **actual** drives corrective action.

```
Goal ──(compare)── Actual
         │
         ↓ gap
    Corrective action ──(+)── Actual (moves toward goal)
```

Often one − link: "more gap → more correction → less gap."

## Anatomy of Balancing Loops

| Property | Description |
|----------|-------------|
| **Goal-directed** | Compares actual to desired state |
| **Opposes deviation** | Pushes back against change |
| **Equilibrium-seeking** | May overshoot (oscillation) if delay is long |
| **Resistance to change** | Existing B-loops explain why initiatives stall |

**Examples:**
- CI test failures → fix code → fewer failures
- High CPU → autoscale → CPU drops
- Budget overrun → spending freeze → budget recovers

## Workflow for AI Agents

### Step 1 — Identify the implied goal

What variable is being held steady? (uptime %, error rate, headcount, latency p99)

If no goal exists, may be R-loop instead.

### Step 2 — Map gap-detection and correction

- What measures actual vs goal?
- What action reduces the gap?
- Trace loop closed back to actual state

### Step 3 — Verify B classification

Count − links in loop; confirm odd.

### Step 4 — Assess loop strength

| Factor | Strong B-loop | Weak B-loop |
|--------|---------------|-------------|
| Correction speed | Fast | Slow / delayed |
| Gain | Large response per unit gap | Small |
| Goal clarity | Explicit metric | Vague |

### Step 5 — Diagnose dysfunction

| Symptom | Cause |
|---------|-------|
| Oscillation | Delay too long; over-correction |
| Stuck far from goal | Weak gain; wrong lever |
| Wrong equilibrium | Goal mis-specified |
| Change resistance | Strong B-loop defending old setpoint |

### Step 6 — Intervention strategy

| Goal | Tactic |
|------|--------|
| **Improve stability** | Strengthen B-loop (faster feedback, clearer goal) |
| **Enable change** | Weaken old B-loop or reset goal first |
| **Reduce oscillation** | Add delay damping; reduce gain |
| **Shift equilibrium** | Change goal/setpoint explicitly; don't fight B-loop |

Changing structure without updating goal → B-loop pulls back.

### Step 7 — Monitor gap metric

Track |goal − actual| over time after intervention.

## Output Template

```markdown
## Balancing Loop — [name]

### Goal / setpoint
p99 latency < 200ms

### Loop diagram
Gap →(+) scale up →(−) latency →(+) reduces gap

### Classification: B (1 negative link)

### Strength: moderate; 5-min delay causes brief overscale

### Dysfunction
Oscillation after traffic spikes

### Interventions
- Hysteresis on autoscale rules
- Raise goal only after structural fix (new setpoint)
```

## Software Engineering Examples

**Healthy B:** Error budget policy — deploys slow when SLO gap widens.

**Resistance:** "We always rollback on any alert" B-loop prevents experimentation.

**Mis-specified goal:** Optimizing test count B-loop → trivial tests; goal should be defect escape rate.

**Change initiative:** New architecture faces B-loop of team habit + runbooks + monitoring tuned to old system.

## Common Mistakes

- Confusing delayed B-loop with R-loop (watch full cycle)
- Fighting B-loop without acknowledging legitimate goal it serves
- Removing B-loop stability without replacement (chaos)
- Multiple nested B-loops at different timescales (fix one, another activates)

## B vs R Interaction

Real systems combine both. R-loop grows users; B-loop caps by server capacity. Strategy: manage which loop dominates at which scale.

## Complementary Skills

- **reinforcing-feedback-loop** — counterpart dynamics
- **connection-circles** — mapping prerequisite
- **iceberg-model** — structures embody B-loops (policies)
- **second-order-thinking** — changing B-loop goals has 2nd-order effects
