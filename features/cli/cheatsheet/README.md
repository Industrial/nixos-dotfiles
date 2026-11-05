# cheatsheet

A three-line router over the help this fleet already has. It exists because something has to
answer `cheatsheet tar`, and because `profiles/cli-core.nix` imports this directory.

| you ask | it answers from | network |
| --- | --- | --- |
| `cheatsheet tar` | the local tldr page cache (`features/cli/tealdeer`) | no |
| a tldr miss | a message naming `navi --query` and `cheatsheet --web` | no |
| `cheatsheet --web tar` | cheat.sh | yes |

This fleet's own commands — `bin/fleet`, `bin/update/*`, the gates, the
`nix eval --raw .#nixosConfigurations.<host>…` idiom — are **not** here. They are `.cheat`
files in `features/cli/navi/cheats/`, reachable with `navi --tag-rules dotfiles`.

## Recommendation: delete this feature

The router earns its keep only as a muscle-memory alias. Everything it does is one word
shorter as `tldr <command>`, and the `--web` escape hatch is `curl cheat.sh/<topic>`. Two
commands and a derivation exist so that one habit survives.

Deleting it is a two-line change that **one leaf cannot make on its own**, because
`profiles/cli-core.nix` is outside this feature's scope and a dangling import breaks every
host:

```diff
--- a/profiles/cli-core.nix
+++ b/profiles/cli-core.nix
@@
     ../features/cli/c
-    ../features/cli/cheatsheet
     ../features/cli/du
```

and `git rm -r features/cli/cheatsheet`. Both in the same commit. Nothing else in the repo
references `cheatsheet` except `.claude-setup/` and `.cursor/`, where the word means
`lean-ctx cheatsheet` and is unrelated.

Until then the feature stays reduced in place: no unconditional `curl`, offline by default.
