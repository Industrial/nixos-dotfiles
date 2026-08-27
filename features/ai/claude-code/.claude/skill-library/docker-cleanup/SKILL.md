---
name: linux-docker-cleanup
description: >-
  Safely reclaim disk space from Docker images, build cache, containers, and
  volumes. Use when docker system df shows high usage, build cache is large,
  or Docker root is under ~/.local/share/docker (rootless). Emphasizes
  assess-first, time-filtered prunes, and never deleting data volumes blindly.
allowed-tools: Read, Shell
---

# Linux Docker Cleanup

Docker does not self-clean. On dev machines, images + build cache often exceed 200–400 GB.

## Assess first (always)

```bash
docker system df
docker system df -v
docker info | rg -i "Docker Root Dir"
du -sh "$(docker info -f '{{.DockerRootDir}}')" 2>/dev/null
```

Rootless Docker stores data at `~/.local/share/docker`, not `/var/lib/docker`.

## What each prune removes

| Command | Removes | Keeps |
|---------|---------|-------|
| `docker container prune` | Stopped containers | Running |
| `docker image prune` | Dangling (`<none>`) images only | Tagged unused images |
| `docker image prune -a` | All unused images | Images used by a container |
| `docker builder prune` | Build cache | Cache used by active build |
| `docker volume prune` | Unused volumes | Volumes attached to any container |
| `docker system prune` | Stopped containers, dangling images, unused networks, build cache | Tagged images, volumes |
| `docker system prune -a` | + all unused tagged images | Images for running containers |
| `docker system prune -a --volumes` | + unused volumes | **Dangerous** — may delete DB data |

## Safe default (time-filtered)

Keeps recent artifacts; good for weekly cron:

```bash
docker system prune --force --filter until=168h
docker builder prune --force --filter until=168h
```

Adjust `168h` (7d) to match deploy/rollback window.

## Targeted high-impact cleanup

**Build cache** (often largest line item):

```bash
docker builder prune --force                    # all unused cache
docker builder prune --force --filter until=72h # keep 3 days
```

**Unused images** (after confirming registries have copies):

```bash
docker image prune -a --force --filter until=168h
```

**Dangling images** (`<none>` tags — safe when nothing references them):

```bash
docker image prune --force
```

## Volumes — extra caution

```bash
docker volume ls
docker volume ls -f dangling=true
docker system df -v   # see which volumes are unused
```

Only prune volumes when you know they hold no needed data:

```bash
docker volume prune --force
```

Never run `--volumes` on production or shared dev DB hosts without a backup and volume inventory.

## Before aggressive prune

1. List running containers: `docker ps`
2. Note images in use: `docker ps --format '{{.Image}}'`
3. Label volumes to keep: `docker volume create --label keep=true mydata`
4. Prune with filter: `docker volume prune --filter "label!=keep"`

## Prevent recurrence

`/etc/docker/daemon.json` (rootful) or rootless equivalent:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

Schedule time-filtered prune via systemd timer or weekly script.

## Expected reclaim on this machine profile

When `docker system df` shows ~78% images reclaimable and ~180 GB build cache:
- `docker builder prune --force` → often 100–180 GB
- `docker image prune -a --force --filter until=168h` → often 100–200 GB
- Combined potential: 300+ GB if many stale CI/build images exist

## Anti-patterns

- `docker system prune -a --volumes -f` without inventory
- Deleting files under `Docker Root Dir` manually
- Pruning on CI hosts that cache layers for speed (use `until=` filter instead)
