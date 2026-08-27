# Mode: REVIEW

`[ID:REVIEW]`

## Goal

Falsify the implementation against plan/AC; run gates; verdict.

## Steps

1. Scrutinize: intent, trace, verify (`engineering/scrutinize`).
2. Diff vs plan: flag any deviation.
3. Run quality gates; `maestro_evidence_record`; `maestro_verdict_request`.
4. PASS → SHIP. FAIL → EXECUTE with concrete fix list.

## Writes

Evidence / notes only. No feature code.

## Exit

[review-exit.md](../checklists/review-exit.md).
