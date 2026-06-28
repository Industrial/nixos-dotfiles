---
name: scientific-method
description: Hypothesis-driven problem solving for improving programs, diagnosing behavior, and choosing fixes. State observations and baselines, generate ranked hypotheses with testable predictions, design controlled experiments that falsify before they confirm, then recommend changes backed by evidence. Trigger on /scientific-method and proactively when the user asks how to improve something, why behavior occurs, what to try next, how to optimize, or wants a rigorous approach to a design or performance question.
---

# Scientific Method

Apply the scientific method to software problems — improvement, diagnosis, optimization, design trade-offs. Recite verbatim, then apply in order.

## Recite this — verbatim, as the first thing in your first response

> **Mantra:**
> 1. **Observe before theorizing.** What is measured, under what conditions, against what baseline?
> 2. **Hypotheses are competing explanations.** Rank them; each must predict something observable.
> 3. **Design to disprove.** The experiment that could kill the leading hypothesis runs first.
> 4. **One variable at a time.** Change one knob; hold everything else fixed.
> 5. **Evidence over elegance.** Accept, reject, or refine — then iterate.

Then begin work.

---

## 1. Observe — characterize the problem

Before proposing solutions, nail down what is known:

- **Phenomenon** — what happens, in one sentence. Symptom, gap, or improvement target.
- **Baseline** — current measured behavior: latency, PnL, error rate, test output, config. A number or a reproducible artifact.
- **Scope** — inputs, environment, version, workload. What is in-bounds vs out-of-bounds.
- **Success criterion** — what would "better" or "fixed" look like, measurably? If this is vague, stop and clarify before hypothesizing.

No baseline → no experiment. Ask for one or propose how to establish it.

## 2. Hypothesize — competing explanations

Generate **3–5 ranked hypotheses**, not one. For each:

- **Claim** — the proposed mechanism or lever (one sentence).
- **Prediction** — if this claim is true, what specific, observable outcome follows? ("If H2 holds, doubling X should halve Y on workload W.")
- **Disproof** — the cheapest observation or experiment that would kill this hypothesis.

Rank by: likelihood given current evidence, cost to test, impact if true. The leading hypothesis is the one to try to disprove first — not the one you hope is right.

## 3. Experiment — controlled, falsification-first

Design the **single next experiment** whose outcome most reduces uncertainty:

- **One variable.** Change one knob (code path, config, input, algorithm). Document what is held constant.
- **Falsify first.** Run the disproof for the leading hypothesis before confirmatory runs.
- **Pre-register expectations.** State predicted outcome before running. After running, compare prediction to observation — don't retrofit the story.
- **Minimal cost.** Prefer the smallest experiment that settles the question: unit test, isolated benchmark, log probe, A/B on one symbol, replay harness.

If the environment cannot run the experiment, say so and propose the smallest runnable substitute. Do not skip to recommendations without evidence.

## 4. Conclude — accept, reject, refine

After each experiment:

- **Verdict** — hypothesis accepted / rejected / inconclusive (with reason).
- **Ledger update** — what changed, what happened, what it ruled in or out. Cross-check new hypotheses against every prior observation.
- **Next step** — one follow-up experiment, or a recommendation backed by the ledger.

Recommendations require at least one experiment that supports them, or an explicit label: *"untested — proposed experiment: …"*.

## 5. Report

Output in this shape:

```markdown
## Observation
[phenomenon, baseline, success criterion]

## Hypotheses
1. **H1** — claim. Predicts: … Disproof: …
2. **H2** — …

## Experiment
[what changed, what held constant, predicted vs actual]

## Conclusion
[verdict, evidence, recommendation or next experiment]
```

Keep it tight. Every recommendation ties to a prediction and an observation.

---

## Operating rules

- Recite the mantra block **once** per session, in your first response. Do not re-recite mid-session.
- Recite **verbatim**. Never paraphrase, shorten, or skip lines.
- If the user says "skip the mantra" → skip the recital but still apply the five steps silently.
- Apply steps **in order**: no hypotheses before baseline; no recommendations before at least one test or an explicit *untested* label.
- **Complements `debug-mantra`.** Use `debug-mantra` when the goal is to find and fix a broken path. Use this skill when the goal is broader: improve, optimize, explain, or choose among approaches.
- The mantra is a constraint **you** carry — not advice to deliver back to the user unless they ask for the framework explicitly.
