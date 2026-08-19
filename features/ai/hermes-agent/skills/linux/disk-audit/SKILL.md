---
name: linux-disk-audit
description: >-
  Audit Linux disk usage to find large directories, caches, and reclaimable space.
  Use when the user asks to analyze disk space, find what's using storage, or
  plan cleanup on / or a home directory. Covers df, du, ncdu, find patterns,
  and prioritization by risk.
allowed-tools: Read, Shell
---

# Linux Disk Audit

Systematic workflow to locate disk consumers before deleting anything.

## Preconditions

- Run read-only commands first; never delete during audit.
- Wrap repo commands with `devenv shell --` when inside a devenv project; system-wide audit uses plain shell.
- Prefer `du -xh` on btrfs/ext4 with sparse files; add `--apparent-size` only when comparing to `df` discrepancies.

## Step 1: Filesystem overview

```bash
df -hT /
df -hi /          # inode exhaustion can block writes despite free space
```

Note `Use%` and mount type. Encrypted LVM (`cryptroot`) is common on NixOS/desktop Linux.

## Step 2: Top-level map (requires patience on large trees)

```bash
sudo du -xh --max-depth=1 / 2>/dev/null | sort -hr | head -20
du -xh --max-depth=1 ~ 2>/dev/null | sort -hr | head -20
```

If `/` scan is slow or permission-denied, drill into known heavy roots:

| Path | Typical contents |
|------|------------------|
| `~` | Code, caches, Docker rootless, models |
| `~/.local/share` | Docker, Trash, app data |
| `~/.cache` | Browser, package manager, compiler caches |
| `/var` | logs, lib, apt (Debian) |
| `/nix/store` | Nix store (NixOS) |

## Step 3: Drill down one level at a time

```bash
du -xh --max-depth=2 TARGET 2>/dev/null | sort -hr | head -25
```

Stop when you identify a category (Docker, `target/`, `node_modules/`, models).

## Step 4: Find common artifact directories

```bash
find ~/Code -type d \( \
  -name target -o -name node_modules -o -name .next -o -name .turbo \
  -o -name dist -o -name .devenv -o -name .venv -o -name __pycache__ \
\) -prune -print 2>/dev/null
```

Sum a pattern:

```bash
du -ch ~/Code/**/target 2>/dev/null | tail -1
```

## Step 5: Tool-specific size checks

```bash
docker system df -v                    # images, build cache, volumes
docker info | rg -i "Docker Root Dir"  # rootless often ~/.local/share/docker
journalctl --disk-usage
nix-collect-garbage --dry-run 2>/dev/null || true
du -sh ~/.cache ~/.npm ~/.cargo ~/.local/share/Trash ~/.lmstudio/models 2>/dev/null
```

## Step 6: Classify findings

| Category | Examples | Reclaim risk |
|----------|----------|--------------|
| **Safe caches** | `~/.cache`, npm/cargo cache, sccache, apt cache | Low — rebuilds on demand |
| **Build artifacts** | `target/`, `dist/`, `.next/` | Low if project inactive; medium if active |
| **Docker unused** | Dangling images, build cache, unused volumes | Medium — verify no needed data in volumes |
| **Docker in-use** | Images for running containers | High — do not prune without check |
| **Data / models** | `~/data`, LM Studio models, research datasets | High — user decision |
| **Git objects** | Large `.git` packs | Medium — `git gc`, not raw delete |
| **Trash** | `~/.local/share/Trash` | Low after user confirms |

## Step 7: Report format

Present results as:

1. **Filesystem summary** — total, used, available
2. **Top 10 consumers** — path, size, category
3. **Reclaimable estimate** — per category with commands (not executed unless asked)
4. **Do not touch** — running services, active project artifacts user may need

## Optional: interactive explorer

```bash
ncdu /home/tom    # install ncdu if missing; best for manual exploration
```

## Anti-patterns

- Do not `rm -rf` during audit.
- Do not assume `/var/lib/docker` — check `docker info` for rootless paths.
- Do not delete `/nix/store` paths manually; use `nix-collect-garbage`.
- Do not delete journal files by hand; use `journalctl --vacuum-*`.
