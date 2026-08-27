# Grafana provisioning on mimir — uid traps & fleet dashboard (verified live 2026-08-24)

## NEVER pin a datasource uid in provisioning against an existing DB

`services.grafana.provision.datasources.settings.datasources.*.uid = "..."`
crash-loops Grafana 13 startup when a datasource of the same NAME already
exists in the DB: provisioner tries to rewrite its uid →
`Datasource provisioning error: data source not found` → background module
`provisioning` fails → process exits → start-limit-hit → deploy-rs
magic-rollback. The rendered YAML looks perfectly fine; only the journal
names the real cause.

Rule: omit `uid` in provisioning; have dashboards reference the datasource's
EXISTING DB-assigned uid. Read it without sqlite3 (not installed on mimir)
straight from the DB bytes:
`sudo grep -a -o -E "PBFA97CFB590B2[A-Za-z0-9]*" /var/lib/grafana/data/grafana.db`
→ live Prometheus datasource uid is `PBFA97CFB590B2093` (stable since db
creation; grafana.db lives at `/var/lib/grafana/data/grafana.db`, NOT
`/var/lib/grafana/grafana.db`).

## Dashboard provider path must be a DIRECTORY

`options.path = ./dashboards/host.json` silently provisions NOTHING (no
error at startup either). Providers scan folders: `options.path =
./dashboards`. Every `.json` inside loads as a dashboard.

## host.json placeholder uids

The imported Node Exporter Full dashboard references `${DS_PROMETHEUS}` and
`000000001` — neither resolves under provisioning (no input vars). Its
panels show "datasource not found" until rewritten to the real uid.
fleet.json (`dashboards/fleet.json`) already uses `PBFA97CFB590B2093`.

## Fleet Overview dashboard shape (features/monitoring/grafana/dashboards/fleet.json)

Fixed `"uid": "fleet-overview"` so re-provisioning UPDATES instead of
duplicating; `"refresh": "10s"` for real-time; one series per host via
Prometheus label `host` (see prometheus scrape labels below); panels:
up-stat / load1 / mem% / cpu busy% / root fs% / net in/out bps with
threshold coloring. Grafana suite in `default.assay.nix` asserts provider-
is-directory, no-uid-pin, per-target datasource uid, panel set, legends.

## Prometheus instance labels

mimir's own scrape target used to be labeled by address (`0.0.0.0:9002`),
making legends unreadable and breaking per-host grouping. Scrape config now
splits static_configs per target with explicit `labels = {host = ...};`
(mimir/drakkar/huginn) — asserted by the prometheus assay.

## Recovery when grafana lands in start-limit-hit

`sudo systemctl reset-failed grafana` before the next deploy, else the new
generation's start hits the failed-state limit immediately.
