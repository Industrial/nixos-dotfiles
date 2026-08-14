---
name: ladder-of-inference
description: Trace reasoning from observable data through selection, interpretation, assumptions, and conclusions to surface hidden leaps and bias. Use to debug flawed conclusions, de-escalate disagreements, and make beliefs explicit before acting.
---

# Ladder of Inference

## Goal

Make the **invisible reasoning chain** visible so the agent (and user) can climb down to observable facts, challenge unwarranted assumptions, and revise conclusions before acting.

Developed by Chris Argyris and Donald Schön.

## When to Use

- Conclusion feels obvious but others disagree
- Debugging "how did we get here?" after a bad decision
- Reviewing blame, intent attribution, or team conflict
- Validating AI-generated conclusions before implementation
- User asks "are you sure?" or evidence is thin

## When NOT to Use

- Purely deductive logic from agreed premises
- Decisions already grounded in measured data with documented chain
- When speed beats reflection (incident triage — revisit after stabilize)

## The Seven Rungs (bottom → top)

```
7. Actions          — what we do based on beliefs
6. Beliefs          — enduring views about how the world works
5. Conclusions      — judgments about this specific situation
4. Assumptions      — unstated premises added to interpretations
3. Interpretations  — meaning assigned to selected data
2. Selected data    — subset of reality we paid attention to
1. Observable data  — what a video camera / logs would capture
```

**Key insight:** We climb the ladder in milliseconds, often skipping rungs. We also **act on conclusions** that rest on **unexamined assumptions**.

## Workflow for AI Agents

### Forward trace (explain a conclusion)

Given a conclusion, walk **down** the ladder:

1. **Action/Belief implied:** What would we do? What belief does this rest on?
2. **Conclusion:** State the judgment explicitly.
3. **Assumptions:** List premises not in the data. Tag each: *verified* | *assumed* | *unknown*.
4. **Interpretation:** How was neutral data given meaning? (e.g., silence → anger)
5. **Selected data:** What was noticed? What was ignored?
6. **Observable data:** What would logs, metrics, transcripts, or files actually show?

### Backward rebuild (grounded conclusion)

Climb **up** only from verified observable data:

1. List observable facts (no adjectives of intent).
2. Add interpretations — label as interpretation, not fact.
3. State assumptions explicitly; mark which need verification.
4. Draw tentative conclusion.
5. Propose action; note what would falsify the conclusion.

### Challenge questions per rung

| Rung | Challenge |
|------|-----------|
| Selected data | What am I not seeing? Who sees differently? |
| Interpretation | What other meanings fit the same data? |
| Assumptions | What must be true for this to hold? Can I test it? |
| Conclusion | If wrong, what would I expect to observe? |
| Beliefs | Is this belief always true? Counter-examples? |

## Output Template

```markdown
## Ladder of Inference — [topic]

### Stated conclusion
...

### Trace (top → bottom)
| Rung | Content | Grounded? |
|------|---------|-----------|
| Conclusion | ... | |
| Assumptions | A1: ... (assumed) | ⚠️ needs test |
| Interpretation | ... | |
| Selected data | ... | |
| Observable data | ... | ✓ from logs |

### Revised conclusion (if needed)
...

### Verification actions
1. Check [metric/log] for ...
```

## Software Engineering Example

**Conclusion:** "The junior dev doesn't care about quality."

| Rung | Bad trace | Better trace |
|------|-----------|--------------|
| Observable | 3 PRs had lint failures | Same |
| Selected | Only failed PRs remembered | Also: 12 clean PRs this month |
| Interpretation | Doesn't care | May lack tooling knowledge |
| Assumption | Intent = negligence | CI config changed last week |
| Conclusion | Doesn't care | Needs lint setup help |
| Action | Escalate to manager | Pair on local pre-commit hooks |

## Common Mistakes

- Stating interpretations as facts ("they're lazy" vs "3 deadlines missed")
- Climbing down only to justify the conclusion (confirmation bias)
- Stopping at assumptions without proposing falsification tests
- Using on others without sharing your own ladder transparently

## Reflexive Loop Warning

Beliefs at rung 6 **filter** what data we select at rung 2 next time. Breaking the loop requires deliberately seeking disconfirming evidence.

## Complementary Skills

- **six-thinking-hats** — White hat = observable data; Black hat = challenge assumptions
- **first-principles** — when assumptions fail, rebuild from constraints
- **inversion** — what observable data would appear if conclusion were false?
