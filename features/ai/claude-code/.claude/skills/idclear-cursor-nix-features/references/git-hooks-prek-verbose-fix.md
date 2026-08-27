# git-hooks-prek `verbose = true` — session transcript

This is the canonical worked example for editing a `.cursor/nix/features/`
module. Read SKILL.md first for the theory; read this for the receipts.

## Symptom

pre-commit / pre-push hooks fire silently — no output unless the hook
fails. User wants the `pre-commit` and `pre-push` scripts (`moon run :lint`,
`moon run :test`, etc.) to stream progress as they run.

## Investigation path

1. **Symlink target is the generated config.**
   `.pre-commit-config.yaml` → `/nix/store/v9bf9m3kwygqsw104xa62sxn4z6dzff9-pre-commit-config.json`.
   Every entry has `"verbose": false`. That field is what controls
   stdout capture behaviour in both Python `pre-commit` and the `prek`
   Rust reimplementation.

2. **Who writes the JSON?**
   `git-hooks.nix` from the cachix `git-hooks.nix` submodule, exposed via
   devenv's `src/modules/integrations/git-hooks.nix`. The submodule
   source lives in `/nix/store/4a3d0gkscakcg2272r42ixcdwif3c7kx-source/`
   in this checkout. The `prek` package lives at
   `/nix/store/7m3xy719rcq90vspd6hpghivww6f9lv9-prek-0.4.10/`.

3. **The per-hook option schema.**
   `/nix/store/4a3d0gkscakcg2272r42ixcdwif3c7kx-source/modules/hook.nix`
   line 201–209:

   ```nix
   verbose = mkOption {
     type = types.bool;
     default = false;
     description = ''
       forces the output of the hook to be printed even when the hook passes.
     '';
   };
   ```

   Serialized at line 259:
   `inherit (config) id name entry language files types types_or
    exclude_types pass_filenames fail_fast require_serial stages
    verbose always_run args;`

   So any hook config that passes `verbose = true` propagates straight
   through to the JSON.

4. **The facade module is `.cursor/nix/features/git-hooks-prek.nix`.**
   That's where this repo wires the `pre-commit` and `pre-push` hooks
   into the `git-hooks.hooks` set. Edit it; `devenv up` regenerates the
   JSON.

## Diff applied

```diff
--- .cursor/nix/features/git-hooks-prek.nix
+++ .cursor/nix/features/git-hooks-prek.nix
@@ -35,6 +35,7 @@
           pass_filenames = false;
           always_run = true;
           language = "system";
+          verbose = true;
         };
 
         pre-push = {
@@ -45,6 +46,7 @@
           pass_filenames = false;
           always_run = true;
           language = "system";
+          verbose = true;
         };
```

Only `pre-commit` and `pre-push` were touched. The `commitizen` hook
(runs on `commit-msg`, no user-visible command output) was left at the
default — flipping it would be noise.

## Verification

- File edit confirmed via `ctx_read` line 30–50: both blocks now carry
  `verbose = true`.
- The JSON regeneration happens automatically on next `devenv up` /
  `devenv shell` re-entry. No manual `prek install` needed because the
  `git-hooks-prek.nix` `install-git-hooks.exec` script already runs in
  `enterShell` (devenv re-entry fires it).
- Stream behaviour visible immediately on next `git commit` /
  `git push`.

## Things NOT tried

- **`prek --verbose` CLI flag.** Would force-verbose all hooks
  regardless of config. Heavier hammer than needed; the per-hook
  option is the right scope.
- **Editing the generated JSON directly.** It's a nix store path;
  any change is overwritten on next devenv regen.
- **Setting `verbose = true` globally on the `git-hooks` set.** Not
  exposed by cachix's submodule at the schema used here; per-hook is
  the only knob.