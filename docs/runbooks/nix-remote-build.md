# Nix remote build (fleet)

Drakkar is the **remote builder** for Mimir and Huginn. Builds offload over Tailscale SSH using the same fleet operator keys as deploy-rs.

## Config

| Host | Module |
|------|--------|
| Drakkar | `features/fleet/nix-remote-builder-server.nix` |
| Mimir, Huginn | `features/fleet/nix-remote-builder-client.nix` (via server/mobile profile) |

Requirements (already satisfied by fleet setup):

- `tom` in `trusted-users` on Drakkar
- Operator SSH keys in `features/fleet/operator-ssh.nix`
- `IdentitiesOnly` + `~/.ssh/id_ed25519` for fleet hosts

## Verify from Mimir or Huginn

```bash
nix show-config | rg 'builders|distributed'
# builders = ssh://drakkar x86_64-linux ...

nix build nixpkgs#hello --print-build-logs
# build may run on drakkar when local machine is busy or max-jobs exceeded
```

Force builder for one shot:

```bash
nix build .#somePackage --max-jobs 0
```

## Drakkar storage

See `hosts/drakkar/DATA.md` — active work under `/data/cache/`, archives on `/mnt/mimir/`.
