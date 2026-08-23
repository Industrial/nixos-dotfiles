---
id: nixos-fleet-management
name: NixOS Fleet Management
description: >-
  Manage Drakkar/Huginn/Mimir via unified flake + deploy-rs. Prefer
  nixos-deploy-rs and nixos-managing skills. Hermes-specific SSH/wrappers are
  out of scope for the multi-host-deploy-rs mission.
---

# NixOS Fleet Management

**Canonical skills:** `nixos-deploy-rs`, `nixos-managing`

**Mission:** `.maestro/specs/multi-host-deploy-rs.md`

**Mimir media stack:** see `references/mimir-media-stack.md` for the enabled
features table with smoke-check units/ports/probes, mimir's container-owned
port budget (5432 logto-db, 5433 yugabyte — NixOS postgres lives on 5434),
the invidious postgresql hba wiring, and the homarr OCI-container rewrite;
run `scripts/verify-media-stack.sh` for combined eval-level + live-runtime
verification of all ten services.

## Do

1. Use root flake `deploy.nodes` + `bin/fleet deploy .#<host>`
2. Keep per-host Disko/hardware under `hosts/<name>/`
3. Disable comin while push-deploy is primary
4. Operator SSH via `~/.ssh/config` — not `~/.hermes/`
5. When planning services, FIRST check `features/media/` and
   `features/monitoring/` for existing fully Nix-managed modules before
   creating new ones
6. Update related runbooks in `docs/runbooks/` when adding new services
7. Verify every change against the evaluated merged config and the live
   host — not just the source files

## Do not

- Install Hermes-only deploy keys or `~/.hermes/bin/nixos-mgmt`
- Activate with Colmena and deploy-rs on the same generation stream
- Invent `colmena rollback` / `colmena update` subcommands
- Expose services to WAN — keep all services Tailscale-only unless absolutely necessary

## Host Roles & Service Assignment

All media and monitoring services already exist as NixOS modules in
`features/media/` and `features/monitoring/` — check existing features before
creating new ones.

| Host | Role |
|------|------|
| Drakkar | Desktop workstation + remote Nix builder; optional media consumption clients |
| Huginn | Tablet/mobile device; minimal profile |
| Mimir | Primary services host: jellyfin, invidious, qbittorrent-nox, *arr family, seerr, prometheus server, grafana; NFS server |

Persistent service data goes in `/data/services/<name>` (NFS-exported so
drakkar/huginn can reach it) — never `/mnt/well`. Mimir's rootless container
stack owns ports 5432 (logto-db), 5433 (yb-tserver) and **9000** (yb-tserver
UI); host-level postgresql uses 5434 and **grafana runs on 3000** (its old
9000 assignment left the unit silently failed across many green deploys —
unchanged units are not restarted by later switches). Prometheus server on
9001 scrapes node exporters fleet-wide via `<host>:9002` targets in its
nodes job. **homarr** runs as an OCI container
(`virtualisation.oci-containers.containers.homarr`, official
`ghcr.io/homarr-labs/homarr` image, port 7575) — the original in-repo
systemd module (`npm start` in an empty dir, no app code) could never work;
see `nixos-media-service-creation` before hand-rolling units for apps that
have no nixpkgs package.

## Service Deployment Planning

### Foundation Analysis
- Review host configs (`hosts/*/configuration.nix`)
- Check existing feature modules first; understand storage/resources per host
- Consult runbooks (`docs/runbooks/*.md`) for deployment patterns

### Implementation Phases
1. Foundation & monitoring (node exporters fleet-wide, grafana on mimir)
2. Storage & media infrastructure (`/data/services/<name>` layout)
3. Service deployment — enable one feature at a time, deploy, smoke-check
   (see `nixos-deploy-rs` → "Enabling features one-by-one")
4. Networking & access (Tailscale-only)
5. Dashboard & integration

### Verification
- `nix flake check` after each module change
- `bin/fleet check <host>` before deploying
- Post-deploy: unit active + local HTTP probe per service
  (`scripts/verify-media-stack.sh` automates this for the mimir media stack)

**Reference**: see `templates/media-service-deployment-plan.md` for a
complete deployment checklist.
