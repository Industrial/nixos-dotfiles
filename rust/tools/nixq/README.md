# nixq

JSON/attrpath query library and CLI on [id_effect](https://github.com/).

**Doctrine:** pure value algebra (`get`, `hasAttrs`, `subset`, `normalize`, `diff`, `force-path`); I/O via DI 3.0 caps (`JsonSource`, `Clock`); CLI = `run_with` + `id_effect_cli` exit codes.

## CLI

```bash
nixq get a.b[0] -f value.json
echo '{"a":1}' | nixq has-attrs a
nixq subset -f actual.json --expected expect.json
nixq force-path a.b -f value.json
nixq normalize -f value.json
nixq diff -f left.json --right right.json
```

Predicate exit: `0` = true, `1` = false, `≥2` = infra (I/O / parse).

## Library

Assay depends on this crate for value-mode helpers (`value_has_attrs`, `value_contains_subset`, `normalize_value`, `structural_diff`).

## Packaging (v1)

Devenv + moon only (`devenv shell -- nixq`, `moon run :nixq-test` / `:nixq-coverage`). No NixOS `features/cli/nixq` module yet.
