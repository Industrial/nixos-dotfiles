---
name: reinforcing-feedback-loop
description: Identify and analyze reinforcing (amplifying) feedback loops where change compounds in the same direction — virtuous growth or vicious decline. Use when you see exponential trends, runaway effects, or compounding dynamics.
---

# Reinforcing Feedback Loop Analysis

## Goal

Detect **R-loops** where an initial change triggers a chain that **amplifies** further change in the same direction — growth, collapse, or runaway.

## When to Use

- Metrics accelerating (growth or decline)
- "Success breeds success" or "death spiral" dynamics
- Viral loops, technical debt accumulation, hype cycles
- After **connection-circles** mapping

## When NOT to Use

- System seeking stable equilibrium (**balancing-feedback-loop**)
- One-time causal chain with no return path
- Linear proportional relationships only

## Identification Rule

In a closed causal loop, count **negative (−) links**:
- **Even count (0, 2, 4…)** → **Reinforcing (R)**
- **Odd count** → Balancing (B)

Zero negatives = all + links = classic amplifying loop.

## Anatomy of Reinforcing Loops

| Property | Description |
|----------|-------------|
| **Self-reinforcing** | Change compounds each cycle |
| **Exponential shape** | Rate of change proportional to current level |
| **No inherent goal** | Unlike B-loops, R-loops don't seek a setpoint |
| **Virtuous or vicious** | Direction depends on initial push |

**Examples:**
- Virtuous: More users → more content → more users
- Vicious: Bugs → overtime → more bugs
- Technical: Load → latency → timeouts → retries → more load

## Workflow for AI Agents

### Step 1 — Confirm trend is non-linear

Linear trends may not be R-loop driven. Look for acceleration in data.

### Step 2 — Map variables and links

Use **connection-circles** notation. Close the loop back to start.

### Step 3 — Verify R classification

Count − links; confirm even.

### Step 4 — Identify loop polarity (virtuous vs vicious)

| Direction | Current push | Outcome |
|-----------|--------------|---------|
| Virtuous R | Positive change at key node | Growth accelerates |
| Vicious R | Negative shock | Decline accelerates |

### Step 5 — Find delay and gain

- **Delay:** time per loop cycle (long delay → slow R; short → fast)
- **Gain:** how much amplification per cycle

### Step 6 — Intervention strategy

| Goal | Tactic |
|------|--------|
| **Break vicious R** | Cut any link in loop (weakest/cheapest) |
| **Slow vicious R** | Add balancing loop (B) or increase delay |
| **Strengthen virtuous R** | Remove friction on strongest + link |
| **Cap runaway virtuous R** | Add B-loop before resource limits hit |

Never rely on R-loop continuing forever — resource limits eventually invoke balancing dynamics.

### Step 7 — Monitor loop health

Track variables on loop; intervention succeeded if acceleration stops or reverses.

## Output Template

```markdown
## Reinforcing Loop — [name]

### Type: R (virtuous / vicious)

### Loop diagram
A →(+) B →(+) C →(+) A

### Mechanism narrative
...

### Cycle time (delay): ~2 weeks
### Current trajectory: accelerating decline

### Interventions
| Lever | Link cut/strengthen | Cost | Expected effect |
|-------|---------------------|------|-----------------|
| Add review bot | D→B | low | slow vicious R |

### Monitoring
- Metric: ...
```

## Software Engineering Examples

**Vicious:** On-call burnout loop (incidents → burnout → mistakes → incidents)

**Virtuous:** Open-source adoption (docs quality → contributors → docs quality)

**Runaway:** Retry storm without backoff (failures → retries → load → failures)

**Intervention:** Exponential backoff + circuit breaker cuts R loop gain.

## Common Mistakes

- Labeling every positive correlation as R-loop (need closed causation)
- Ignoring delays (loop not visible in daily metrics)
- Strengthening virtuous R past infrastructure capacity
- Forgetting external B-loops (market saturation, regulation)

## Complementary Skills

- **balancing-feedback-loop** — stabilizing counterpart
- **connection-circles** — mapping prerequisite
- **second-order-thinking** — R-loops are often 2nd-order effects
- **iceberg-model** — structures that create R-loops
