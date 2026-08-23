# Homarr — deployment facts (verified live 2026-08-23)

## What Homarr actually is (why oci-containers)

- Upstream ships ONLY an OCI image: `ghcr.io/homarr-labs/homarr:latest`
  (label version "main"). No nixpkgs package (`pkgs.homarr` does not exist;
  nearest names are homer/hoard), no `services.homarr` NixOS module in the
  pinned nixpkgs.
- App is a Next.js monorepo with embedded redis + sqlite tooling — packaging
  it natively is a real project, not a module file. Hence
  `virtualisation.oci-containers` is the correct integration tier.

## Configuration storage (from homarr.dev docs + live inspection)

Docs source: homarr.dev → Getting started → Installation → Docker
(source of truth: github.com/homarr-labs/documentation,
docs/getting-started/installation/docker.mdx, master branch — note the
repo uses `master` not `main`; raw.githubusercontent on `main` 404s).

Official run command mounts exactly ONE state volume:

    docker run ... -p 7575:7575 \
      -v <your-path>/homarr/appdata:/appdata \
      -e SECRET_ENCRYPTION_KEY='your_64_character_hex_string' \
      -d ghcr.io/homarr-labs/homarr:latest

On the fleet (features/media/homarr/default.nix):

    /data/services/homarr/appdata  ->  /appdata   (the state that matters)
    /data/services/homarr/data     ->  /data      (currently UNUSED by app;
                                                   kept for compat)

Live contents of /data/services/homarr/appdata (2026-08-23):

    db/db.sqlite                 6.7 MB  ← ALL configuration: boards, users,
                                           integrations, API keys
    redis/                       ephemeral runtime state
    trusted-certificates/        CA certs the user trusted in UI

**Backup = copy `appdata/db/db.sqlite`.** Restore = stop container, drop
file back, start.

`SECRET_ENCRYPTION_KEY` (64 hex chars) is mandatory; losing it means stored
secrets (integration credentials) become undecryptable. Ours is generated
once and committed in the module (private-repo acceptable).

## Runtime/verification quirks

- `docker-homarr.service` (oci-containers unit) reports `inactive` while the
  app serves fine — the unit hands off to the docker daemon. Never judge
  health by systemctl here; probe HTTP:
      curl http://127.0.0.1:7575/            → 307 (healthy redirect)
      curl http://127.0.0.1:7575/manage/tools → 307
  Unknown API routes return JSON `{"message":"Not found","code":"NOT_FOUND"}`
  with the tRPC wrapper — that is the app answering, not a proxy.
- First browser visit walks through user creation (setup wizard).
- Updating = remove container + pull + recreate (docs recommend compose for
  convenience; oci-containers handles this declaratively).

## Assay suite

`features/media/homarr/default.assay.nix` asserts module shape with stubbed
args (`pkgs = {}` suffices — the module only interpolates pkgs inside
strings): official image string, ports ["7575:7575"], an /appdata volume,
SECRET_ENCRYPTION_KEY present, firewall 7575.
