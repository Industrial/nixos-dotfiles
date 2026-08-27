# Consumer-repo duplicate `nix/` facade cleanup — session transcript

This is the canonical worked example for the "Consumer-repo duplicate
`nix/` facade" pitfall in SKILL.md. Read SKILL.md for the rules; read
this for the receipts.

## Symptom

`devenv up` fails with a duplicate-option error after pulling the
`.cursor` submodule forward:

```
error: The option `cursor.features.program-hermes.enable' in
`/data/Code/idclear/monorepo/nix/features/program-hermes.nix' is
already declared in
`/data/Code/idclear/monorepo/.cursor/nix/features/program-hermes.nix'.
```

The pre-commit/pre-push script output now also shows the underlying
stack:

```
… while evaluating the option `packages':
… while evaluating definitions from
   `/data/Code/idclear/monorepo/.cursor/nix/features/program-hermes.nix':
```

The parent monorepo has a parallel `nix/` directory shadowing the
canonical `.cursor/nix/` facade.

## Discovery

`git status` shows `.cursor (modified content)` and `M devenv.nix` —
typical submodule-bump state. `cd .cursor && git log --oneline -5`
confirms the submodule now imports a tighter facade (no serena, no
duplicates). The duplicate-option error is the parent repo paying for
its copy-paste history: `nix/features/program-hermes.nix` in the
parent is **byte-identical** to the same file in the submodule.

`comm` is the right tool to enumerate what the parent needs to drop:

```bash
cd nix/features && ls -A > /tmp/parent.txt
cd .cursor/nix/features && ls -A > /tmp/cursor.txt
comm -23 <(sort /tmp/parent.txt) <(sort /tmp/cursor.txt)   # only in parent
comm -12 <(sort /tmp/parent.txt) <(sort /tmp/cursor.txt)   # common (dupes to diff)
```

In this checkout, the only files in parent but not cursor were `program-serena.{nix,assay.nix}`
+ the `serena/` directory (the submodule removed serena). Every other
file in the parent's `nix/features/` was a duplicate of one in
`.cursor/nix/features/`.

## Diff before delete

For every common file:

```bash
for f in context7 hermes-agent maestro omniroute roam-code; do
  diff -rq nix/features/$f .cursor/nix/features/$f
done
for f in program-context7 program-hermes program-maestro \
         program-omniroute program-roam-code-pypi; do
  for ext in nix assay.nix; do
    diff -q nix/features/$f.$ext .cursor/nix/features/$f.$ext
  done
done
```

In this session, all 10 `.nix` / `.assay.nix` files were identical;
4 of 5 directories were identical; only
`nix/features/hermes-agent/templates/config.yaml` differed (parent
had a `serena:` MCP block the submodule dropped when it removed
serena). That serena block went with the file deletion.

## Cleanup sequence

After the diff confirms duplicates are safe to delete:

```bash
cd nix
git rm devenv.nix devenv.assay.nix
rm -rf features/context7 features/hermes-agent features/maestro \
       features/omniroute features/roam-code features/serena
rm features/program-{context7,hermes,maestro,omniroute,\
   roam-code-pypi,serena}.{nix,assay.nix}
rmdir features     # when empty
```

Then update the three places that referenced the deleted paths:

- `devenv.nix` `enterShell` block: replace `nix/features/hermes-agent/templates/...`
  with `.cursor/nix/features/hermes-agent/templates/...` (3 lines).
- `devenv.nix` `cursor.features.<x>.enable = true;` list: drop any
  features that no longer exist in `.cursor/nix/features/` (in this
  case `program-serena`).
- `AGENTS.md` and any other doc reference.

## Replace `nix/moon.yml` with a `nix-test` task

The parent's `nix/moon.yml` (id `library`, runs `assay run '.'`) was a
child-project because the parent's `moon.yml` is `id 'application'`.
Drop the sub-project entirely; add this to the root `moon.yml`:

```yaml
nix-test:
  description: 'Assay suites for .cursor/nix (canonical feature stack)'
  command: 'assay'
  args: ['run', '.cursor/nix']
  inputs:
    - '.cursor/nix/**/*.nix'
    - '.cursor/nix/default.assay.nix'
    - '.cursor/nix/devenv.assay.nix'
    - '.cursor/nix/default.nix'
    - '.cursor/nix/devenv.nix'
    - '.cursor/nix/devenv.yaml'
    - '.cursor/nix/lib/**/*'
  options:
    cache: true
    runInCI: true
    outputStyle: buffer-only-failure
```

Wire it into the pre-push gate so CI exercises the canonical stack:

```nix
cursor.features.git-hooks-moon = {
  enable = true;
  preCommitTargets = ":lint :test --affected remote --cache off";
  prePushTargets = ":lint :test :coverage :nix-test --affected remote --cache off";
};
```

## Net diff

10 files changed: 6 deleted (the entire `nix/` directory), 4 modified
(`devenv.nix`, `moon.yml`, `AGENTS.md`). Net `+25 / -90`.

## Things NOT tried

- **Merging `nix/default.assay.nix` into `.cursor/nix/default.assay.nix`.**
  The parent's assay was redundant (asserted 5 of the 21 features
  the canonical suite already validates). Deleting it loses nothing.
- **Keeping `nix/` as a minimal regression-test surface.** A valid
  alternative (keep `nix/moon.yml` + `nix/default.assay.nix`, drop
  the rest). The user chose "drop nix entirely" so we went that way.
- **Renaming `nix/` to `tests/nix-assay/`.** Cosmetic only; would
  churn docs and CI paths without changing the surface.