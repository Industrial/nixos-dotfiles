# vci

The fleet's CI on the cache host (GH-242). It builds every fleet host's toplevel for `main`
and every open same-repository PR, in the store vcache serves, so a built commit is in the
cache with nothing pushed and a deploy of it only substitutes. Each result is recorded
with its eval and build time. Written in Voltaic 0.3.0 (`src/*.vlt`, compiled by
`build.rs`) with id_effect 0.13.0. It links vdeploy's command runner and vdiff as
libraries; neither is changed.

```
vci --host NAME [--host NAME...] [--once] [--url URL] [--branch NAME]
    [--pulls-url URL | --no-pulls] [--repo-slug OWNER/REPO] [--repo DIR]
    [--state-dir DIR] [--textfile-dir DIR] [--interval DURATION]
    [--status-token-file FILE] [--api URL] [--git PROG] [--curl PROG] [--nix PROG] [--db FILE]
    [--systemctl PROG] [--max-load N] [--min-free-memory SIZE] [--own-host NAME]
```

## One step

Every `--interval` (2 minutes in the feature), on a spaced id_effect Schedule:

1. **List**: `main` with `git ls-remote <url> refs/heads/<branch>`, and the open PRs from
   GitHub's `GET /repos/<slug>/pulls?state=open`. Both are read **without a token**: the
   repository is public, and the unauthenticated API allows 60 requests an hour, of which
   one step makes one. Only **same-repository** PRs are kept (head repo = base repo =
   `--repo-slug`). A fork's PR is someone else's code, and vci evaluates and builds what
   it is given. `refs/pull/*/head` is never listed: GitHub keeps it for every PR ever
   opened. Listing and fetching are retried on a bounded exponential Schedule (10 s, 20 s).
2. **Fetch** those heads into vci's own bare clone (`/var/lib/vci/repo`), as
   `refs/vci/main` and `refs/vci/pull/<n>`.
3. **Prune**: the result roots of refs that are gone (a merged or closed PR, a host that
   left the fleet) are dropped, so vgc can collect what only they kept.
4. **Pick** the next commit (`refs.vlt` `next_of`): main first (deploys follow it), then the
   PRs newest first. A commit is built once, whichever ref names it.
5. **Build it for every host**, one after another, in `--host` order except that
   `--own-host` (the host vci runs on, the feature's `ownHost` = `networking.hostName`)
   goes first when it is one of them (GH-287): the cache host's vdeploy plans a new commit
   at once, so its veval record has to be written before the others':
   `nix eval --raw git+file://<repo>?rev=<sha>#nixosConfigurations."<host>".config.system.build.toplevel.drvPath`,
   then `nix build --out-link /var/lib/vci/roots/<ref>-<host> <drv>^out`. Each out-link is
   an indirect GC root. For a PR, vdiff's summary against main's generation for the same
   host (packages changed, added, removed, closure size delta). One host failing is its
   own result, never the commit's: the others are still built, and the commit is done.
6. **Record** (and, for a built host, its veval record: below) one line per (commit, host) in `/var/lib/vci/builds.jsonl` (schema 1:
   `sha`, `ref`, `host`, `result` built / eval-failed / build-failed, `drv`, `out`,
   `evalSeconds`, `buildSeconds`, `error`, `diff`, `at`), a marker in `done/<sha>`, and
   `vci.prom` in the textfile directory.

A commit is done once every host has a result, failures included. It is not built again
until its ref moves to a new commit. When a failure was the machine's and not the
commit's, `rm /var/lib/vci/done/<sha>` (as root) has the next step build it again.

A step builds one commit to its end. A build in flight is never cancelled because a ref
moved; the next step lists again and takes the newest heads then (latest-wins). The long
steps are tokio child processes (vdeploy's `exec`), so an hour-long build holds no
executor thread. Ctrl-C or a systemd stop kills the child with its fiber.

## Shared evaluations (veval, GH-243)

vdeploy and vswitch evaluate the same (commit, host) vci already evaluated: the drv is
identical (34 of 34 plans checked on drakkar and mimir, #243). So every host vci **builds**
also gets a record, `/var/lib/vci/veval/<key id>.veval` (nix-store-core's `veval`), written
after the build so that a consumer's hit always finds the out in the cache:

```
Version: veval-1
Key: <sha256 of the fields below>
Form: git+file?rev
Commit: <sha>
Tree: <git rev-parse sha^{tree}>
Lock: <git rev-parse sha:flake.lock>
Host: mimir
Nix: nix (Nix) 2.31.2
Drv: /nix/store/…-nixos-system-mimir-….drv
Out: /nix/store/…-nixos-system-mimir-…
EvalSeconds: 32
```

The key is the commit, not the tree: `self.rev` is an evaluation input
(`system.configurationRevision`), so one tree at two commits evaluates to two toplevels.
`Nix` is the evaluating `nix --version`, so two Nix versions never share a record. The
record is unsigned; vcache serves it at `GET /veval/<key id>.veval` signed at serve time with
the key it signs narinfos with, so vci never holds a key. An eval-failed or build-failed
host, or a commit without a `flake.lock`, has no record. Records older than two weeks are
removed at the start of a step. Nothing here can fail a step: a record that is missing is
a consumer's miss.

## Metrics

| metric | |
|---|---|
| `vci_eval_seconds{host,ref}` | the latest evaluation, `ref` = `main` or `pr` |
| `vci_build_seconds{host,ref}` | the latest build |
| `vci_last_result{host,ref,result}` | 1 for the result it had |
| `vci_commits_built_total` | commits built for every host |
| `vci_pending_commits` | open heads not built yet |
| `vci_last_build_timestamp_seconds`, `vci_last_step_timestamp_seconds` | liveness |

The eval seconds per host, and how often a commit leaves a host's `drv` unchanged, are
what veval (#243) is decided on.

## Commit statuses (off by default)

Without `--status-token-file`, vci posts nothing: the PR's CI result stays GitHub
Actions'. With it, every host gets a `vci/<host>` status on every commit vci builds:
`pending` when it starts, then `success` ("built in 3m12s (eval 41s) · 4 changed, 1 added,
0 removed, +12.3 MiB vs main") or `failure`. The token is read from the file at every
post, so whatever mints it can replace it. It is handed to curl on stdin as a header,
never in argv or the environment. The NixOS feature passes the file with systemd's
`LoadCredential` (option `statusTokenFile`, null by default). The intended token is an
installation token of the GitHub App the user is creating for vbump (#189, #228), with
**Commit statuses: Read and write** added. Minting and refreshing that token is not part
of vci yet; see the PR.

## Tests

- `src/*.vlt` (cargo test, also the package's checkPhase):
  - which commit is next;
  - forks and deleted head repos refused;
  - root names and pruning;
  - the record's JSON round trip;
  - the metrics' bounded labels;
  - the status text in 140 characters;
  - the ledger on disk;
  - a token file never reaching argv;
  - whole steps against a scripted world: main first, then the PR with its diff, one
    host's failure isolated, statuses per host, a forge that is down, a closed PR's roots
    dropped.
- `features/nix/vci/test.nix` (`nix build .#checks.x86_64-linux.vci-vm`): a cache node
  with vcache and a restricted daemon, switched into vci live and out again, against a
  local repository and open-PR list:
  - main built for both hosts, with roots and metrics;
  - a client substituting the result with `max-jobs 0` (zero local builds);
  - a same-repository PR built with its diff, and a fork's PR never;
  - one host failing to evaluate without stopping the other;
  - a closed PR's roots dropped.
