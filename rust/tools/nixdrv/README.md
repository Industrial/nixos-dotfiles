# nixdrv

Derivation ATerm/JSON parse, field projection, and content-addressed store-path helpers on [id_effect](https://github.com/).

**Doctrine:** pure derivation algebra (`parse`, `project`, `fixed_output_path`); I/O via DI 3.0 caps (`DrvSource`, `Clock`); CLI lands in a later leaf.

## Library

- `parse_drv_aterm` — classic Nix `.drv` ATerm
- `Derivation::from_json` — `nix derivation show`, bare JSON, eval-like projections
- `project` — selective field export for assay consumers
- `fixed_output_path` / `text_path` — CA store-path computation (no FS NAR walker)

Assay and nixq depend on this crate for derivation-shaped values.

## Packaging (v1)

Devenv + moon only (`devenv shell -- cargo test -p nixdrv`). No NixOS module yet.

## Non-goals

- Building or realising derivations
- Walking the filesystem to compute NAR hashes
- Full Nix evaluator / store protocol
