# Authoring Colocated Assay Suites (dotfiles repo)

Session-proven patterns for writing `<stem>.assay.nix` unit tests beside Nix
modules/packages. Source: 2026-08-23 assay-gap inventory (7 new suites,
full gate 582/582).

## Harness API (`common/assay/default.nix`)
- `suite "name" { caseName = claim; ... }`
- Eager claims (values evaluated at suite construction): `eq actual expected`,
  `subset actual expected`, `hasAttrs actual ["a" "b"]`.
- Lazy claims (keep expr STRINGS): `throws "expr" pattern`, `forces expr paths`,
  `snapshot`, `module`, `drv`, `pathInfo`.

## Claim Semantics Gotchas
- `subset a b`: attrsets -> key containment (actual ⊇ expected). LISTS ->
  POSITIONAL prefix comparison, not membership. For list containment write:
  `assay.eq (builtins.all (u: builtins.elem u actual wanted) wanted) true`.
- `builtins.match` is POSIX ERE, not PCRE: backslash escapes like `\[` are
  invalid ("invalid regular expression"); write a literal bracket as `[[]`.
  Prefer matching distinctive prose/comment fragments over bracket-dense syntax.
  Patterns also do NOT cross newlines — for multi-line text use `(.|\n)*`.
- Stub-import a module with EXACTLY the formals it declares; passing extras
  fails with "called with unexpected argument". Read the module header first.
- Nix `or` is not a binary operator (`meta = meta or {}` is a parse error;
  nixf flags `'or' keyword is not a binary operator`). Put defaults inside the
  stub instead.
- Assert generated JSON env payloads with `builtins.fromJSON` on the string.
- Relative imports are depth-sensitive: count directory levels carefully
  (`./../../../common/assay/default.nix`); a wrong count surfaces as
  "path ... does not exist" pointing at the joined path.

## Module-Suite Skeleton (stub import)
```nix
let
  assay = import ./../../../common/assay/default.nix;  # depth varies
  mod = import ./default.nix { pkgs = {}; lib = {}; config = {}; };
in assay.suite "name" {
  shape = assay.eq mod.some.option expected;
}
```
Reference exemplar: `features/media/seerr/default.assay.nix`.
Complex case with writer stubs: `features/media/arr-wiring.assay.nix`
(stub `writeShellScript`/`writers.writePython3` as `name: text: {inherit name text;}`,
then assert on the returned `.text`).
When the module interpolates a TOOL into generated script text (e.g.
`${pkgs.diffutils}/bin/cmp`), the stub value must be the STORE PATH WITHOUT
the binary (`diffutils = "/nix/store/xxx-diffutils"`) — a full binary path
double-appends `/bin/cmp` and any path-regex assertion then mismatches.
Keep the stub set in sync whenever the module adds a `pkgs.<tool>`
reference, or eval fails with `attribute '<tool>' missing`.

## Package-Suite Skeleton (eval-only, no network/build)
Stub `rustPlatform.buildRustPackage`, `fetchFromGitHub`, minimal `lib`; import
`package.nix` with exactly its declared args; assert pname/version/meta/fetcher
pins. Reference: `features/cli/usbtree/package.assay.nix`.
String-level alternative (no eval): `builtins.readFile` + `match`
(reference: `features/ai/hermes-agent/package.assay.nix`).

## Generated Files
For crate2nix output (e.g. `Cargo.nix`): no behavioural suite. Guard that it
imports with stub args and exposes stable public attrs (`rootCrate`,
`workspaceMembers`). Mark "generated — regenerate, don't hand-edit".
Reference: `rust/tools/oomkiller/Cargo.assay.nix`.

## Sensitive Data
Secrets modules (API keys): assert key SET + value SHAPE only (length/charset
via match). Never print values into claims, messages, or snapshots — runner
output renders actual/expected verbatim.

## Gap-Inventory Method
1. `find` non-assay `*.nix` excluding `.git/`, `.cursor/`; sibling
   `<stem>.assay.nix` existence check.
2. FILTER TO GIT-TRACKED (`git ls-files --error-unmatch`) — devenv state dirs
   and nested runtime trees otherwise pollute results.
3. Beware HEAD-vs-worktree drift: a complement can exist at HEAD but be
   deleted locally -> false gap. Check `git log --oneline -- <path>` /
   `git show HEAD:<path>` before rewriting, and preserve every original
   assertion when you supersede it (homarr case, commit d1445335).

## Repo Workflow Pitfall (hooks)
Outside `devenv shell`, the meta hooks whose entry is the literal command
`pre-commit` / `pre-push` fail ENOENT AFTER the real gates pass. Fix: run git
operations from `devenv shell`, or `SKIP=pre-commit` (commits) /
`SKIP=pre-push` (pushes) — `moon-test (assay)` and `deepsec` still execute.

## Off-Limits Paths
Never create/modify/delete anything under `.hermes/` (repo root or
`features/ai/hermes-agent/.hermes/`) during feature work — user directive
2026-08-23. The hermes-plugin `templates/package.nix` files there are exempt
from assay coverage; record such exemptions in the repo `history/` ledger.

## Verification-Script Discipline (Hermes gate)
When the Hermes system prompt demands ad-hoc verification of changed paths,
write ONE script under `/tmp/hermes-verify-<topic>.sh` that (1) runs the
colocated suite, (2) re-checks key claims directly via `nix-instantiate
--eval`, and (3) for service changes, probes the LIVE target over ssh.
Expect to iterate on the SCRIPT, not the module: two recurring self-bugs —
`builtins.match` patterns don't cross newlines (`.*` fails on multi-line
activation text; use `(.|\n)*`) and stub values must mirror reality (a
module interpolating ``${pkgs.diffutils}/bin/cmp`` needs a DIRECTORY stub
like `/nix/store/xxx-diffutils`, not a full binary path). A FAIL from your
own harness is not a module regression; fix the harness before touching
code. Permission-gate note: `rm /tmp/...` cleanup may be denied — leave the
script and say so rather than retrying.
