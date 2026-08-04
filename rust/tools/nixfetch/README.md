# nixfetch

Fixed-output `fetchurl` / `fetchgit` download and flat/NAR hash verification on id_effect.

**Doctrine:** Pure hash/NAR/verify algebra; I/O via DI 3.0 caps (`HttpFetch`, `GitFetch`, `PathIo`, `Clock`); CLI = `run_with` + `id_effect_cli` exit codes.

## CLI

```bash
nixfetch hash --flat path/to/file
nixfetch hash --recursive path/to/dir
nixfetch verify --expected sha256-… --flat path/to/file
nixfetch fetch-url https://example.com/tarball.tar.gz --hash sha256-…
nixfetch fetch-git https://example.com/repo.git --rev abc123 --hash 0…
nixfetch store-path --name pkg --hash sha256-… [--recursive]
```

Exit: `0` match/success, `1` hash mismatch, `≥2` infra.

## Library

- Flat SHA256 and recursive NAR SHA256
- Parse expected digests: SRI, hex, Nix base32
- `fixed_output_path` via path-dep `nixdrv`

## Packaging (v1)

Devenv + moon only (`devenv shell -- cargo test -p nixfetch`, `nixfetch-coverage`). No NixOS module yet.

## Non-goals

- Store realise / register / GC
- Auto-unpack of tarballs
- Full Nix evaluator / daemon
- Assay `Claim::Fetch` (deferred)
