---
name: linux-disk-cleanup-plan
description: >-
  Produce a prioritized, risk-rated disk cleanup plan from audit findings.
  Use after linux-disk-audit to recommend what to remove, estimated savings,
  commands to run, and what requires user confirmation. Orchestrates
  docker-cleanup and dev-caches-cleanup skills.
allowed-tools: Read, Shell
---

# Linux Disk Cleanup Plan

Turn audit data into an actionable, staged plan. **Execute commands only when the user approves each stage.**

## Risk tiers

| Tier | Definition | Examples |
|------|------------|----------|
| **A — Safe** | Regenerates automatically | package caches, build cache, Trash, sccache |
| **B — Rebuild cost** | Safe but costs time | `cargo clean`, `node_modules`, `.devenv` |
| **C — Confirm** | May be intentional data | `data/`, datasets, LM models, Docker volumes |
| **D — Do not touch** | System or active state | `/nix/store` manual deletes, running container images |

## Plan template

```markdown
## Disk cleanup plan — HOSTNAME — DATE

**Filesystem:** X used / Y total (Z% full)

### Stage 1 — Quick wins (Tier A, ~N GB)
- [ ] Command — est. savings — notes

### Stage 2 — Docker (Tier A/B, ~N GB)
- [ ] See linux/docker-cleanup

### Stage 3 — Build artifacts (Tier B, ~N GB)
- [ ] Per-project list

### Stage 4 — User confirmation (Tier C)
- [ ] Items needing explicit yes

### Do not touch
- ...

**Estimated total reclaim:** N–M GB
```

## Staging rules

1. Run Stage 1 before Stage 2 so Docker daemon has room for metadata ops.
2. After each stage: `df -h /` and verify services still start.
3. Never combine `docker system prune -a --volumes` with other destructive ops in one script without checkpoints.

## Verification after cleanup

```bash
df -h /
docker system df
du -sh ~/Code ~/.cache ~/.local/share/docker 2>/dev/null
```

## When disk is 100% full (emergency)

```bash
sudo journalctl --vacuum-size=100M
docker builder prune --force
rm -rf ~/.cache/sccache
# truncate only as last resort:
# sudo truncate -s 0 /var/log/syslog
```

Then run full audit when headroom exists.

## Related skills

- `linux/disk-audit` — find consumers
- `linux/docker-cleanup` — Docker-specific commands
- `linux/dev-caches-cleanup` — language/tool caches
