# Docker skills for Cursor

Curated, production-oriented Docker agent skills installed under `.cursor/skills/docker/`. Cursor discovers nested skill folders the same way as `.cursor/skills/thinking/*/SKILL.md`.

**26 skills** across Dockerfile authoring, Compose, security, CI/CD, troubleshooting, and scaffolding.

## Quick pick

| Task | Skill |
|------|-------|
| idclear local dev vs VPS prod compose modes | `idclear-docker-compose-modes` |
| Dockerize a new app (Cursor workflow) | `adding-docker` |
| Practical Dockerfile / compose / debug | `docker-helper` |
| Production patterns + deep reference | `containers-orchestration` |
| Generate Dockerfile + compose from scratch | `docker-agents-generator` |
| Review Dockerfile / compose before deploy | `docker-agents-review` |
| Build failures | `docker-errors-build` |
| Container crashes / OOM / exits | `docker-errors-runtime` |
| Compose won't start | `docker-errors-compose` |
| Container networking / DNS | `docker-errors-networking` |
| Multi-stage builds | `docker-syntax-multistage` |
| BuildKit cache / secrets / mounts | `docker-syntax-buildkit` |
| GitHub Actions image publish | `docker-impl-cicd` |
| Local dev with compose watch / profiles | `docker-impl-compose-workflows` |

## Full catalog (Impertio / OpenAEC package — 22 skills)

### Core
- `docker-core-architecture` — Engine, containerd, OCI, layers, lifecycle
- `docker-core-security` — Scout/Trivy, rootless, capabilities, seccomp, Bench
- `docker-core-networking` — Drivers, DNS, port publishing, isolation

### Syntax / reference
- `docker-syntax-dockerfile` — Instruction reference (FROM, RUN, CMD, …)
- `docker-syntax-buildkit` — Cache mounts, secret mounts, heredocs
- `docker-syntax-multistage` — Stage patterns, `--target`, artifact copy
- `docker-syntax-compose-services` — Service attributes, health, deploy
- `docker-syntax-compose-resources` — Networks, volumes, configs, secrets
- `docker-syntax-cli-containers` — `docker run`, exec, logs, lifecycle
- `docker-syntax-cli-images` — build/buildx, push, prune, save/load

### Implementation
- `docker-impl-build-optimization` — Layer cache, `.dockerignore`, CI cache
- `docker-impl-production` — Distroless, non-root, signals, HEALTHCHECK
- `docker-impl-storage` — Volumes vs bind mounts, backup, persistence
- `docker-impl-cicd` — GitHub Actions, GHCR, multi-platform buildx
- `docker-impl-compose-workflows` — Profiles, overrides, compose watch
- `docker-impl-go-templates` — `--format` templates for inspect/ps

### Errors / diagnostics
- `docker-errors-build`, `docker-errors-runtime`, `docker-errors-compose`, `docker-errors-networking`

### Agents
- `docker-agents-generator`, `docker-agents-review`

## Additional skills (3)

- `containers-orchestration` — [d-padmanabhan/cursor-engineering-rules](https://github.com/d-padmanabhan/cursor-engineering-rules) (+ `references/docker.md`)
- `docker-helper` — [TerminalSkills/skills](https://github.com/TerminalSkills/skills) (Apache-2.0)
- `adding-docker` — [spencerpauly/awesome-cursor-skills](https://github.com/spencerpauly/awesome-cursor-skills)

## Related skill in this repo

`.cursor/skills/docker-expert/` remains a single broad “Docker expert” skill. Prefer the focused skills above for specific tasks to keep context smaller.

## Sources & licenses

| Source | Skills | License |
|--------|--------|---------|
| [Impertio-Studio/Docker-Claude-Skill-Package](https://github.com/Impertio-Studio/Docker-Claude-Skill-Package) (OpenAEC Foundation) | 22 | MIT |
| [d-padmanabhan/cursor-engineering-rules](https://github.com/d-padmanabhan/cursor-engineering-rules) | 1 | See upstream repo |
| [TerminalSkills/skills](https://github.com/TerminalSkills/skills) | 1 | Apache-2.0 |
| [spencerpauly/awesome-cursor-skills](https://github.com/spencerpauly/awesome-cursor-skills) | 1 | See upstream repo |

Installed from upstream **v1.1.1** (Impertio package, March 2026). Each skill may include a `references/` directory with extended docs, examples, and anti-patterns.

## Updating

```bash
# Re-fetch Impertio package (22 skills)
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/Impertio-Studio/Docker-Claude-Skill-Package.git "$TMP/pkg"
find "$TMP/pkg/skills/source" -mindepth 2 -maxdepth 2 -type d | while read -r d; do
  cp -a "$d" ".cursor/skills/docker/$(basename "$d")"
done
```
