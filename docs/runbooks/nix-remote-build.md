# Nix remote build (fleet)

**Mimir** offloads builds to the rest of the fleet over SSH (Tailscale), using the same
operator keys as deploy-rs. It is the only build client.

## Config

| Host | Module | Role |
|------|--------|------|
| mimir | `features/fleet/nix-remote-builder-client.nix` | client: `nix.distributedBuilds = true` |
| drakkar, huginn, muninn | `features/fleet/nix-remote-builder-server.nix` | builder: advertises `nixos-test benchmark big-parallel kvm` |

The client's `nix.buildMachines`, in the order it lists them:

| Builder | maxJobs | speedFactor | Features |
|---------|---------|-------------|----------|
| drakkar | 8 | 2 | `big-parallel kvm nixos-test` |
| muninn | 4 | 1 | `kvm nixos-test` |
| huginn | 4 | 1 | `kvm nixos-test` |

Nix skips a builder it cannot reach, so an offline host only costs a connection attempt.
`builders-use-substitutes = true` lets builders fetch from the binary cache themselves
instead of receiving every dependency from mimir.

Requirements (already satisfied by fleet setup):

- `tom` in `trusted-users` on the builders (`features/nixos/users`)
- Operator SSH keys in `features/fleet/operator-ssh.nix`
- `IdentitiesOnly` + `~/.ssh/id_ed25519` for fleet hosts

## Verify from mimir

```bash
nix show-config | rg 'builders|distributed'
# builders = ssh://drakkar x86_64-linux ... ; ssh://muninn ... ; ssh://huginn ...

nix build nixpkgs#hello --print-build-logs
# build may run on a builder when the local machine is busy or max-jobs is exceeded
```

Force remote building for one shot:

```bash
nix build .#somePackage --max-jobs 0
```

## Drakkar storage

See `hosts/drakkar/DATA.md`: active work under `/data/cache/`, archives copied to mimir's
`/data/archive/`.
