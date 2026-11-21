# vwhy

Why one Nix store path depends on another, and what a closure's size is made
of, read straight from the store database. It replaces `nix why-depends` and
nix-tree for day-to-day use (GH-182). Written in Voltaic 0.2.1 (`src/*.vlt`,
compiled by `build.rs`) with id_effect 0.13.0; the store primitives are
nix-store-core's, and package names are parsed by vdiff's parser
(`vdiff::version::parse_name`), shared rather than copied.

```
vwhy [--json] [--all] [--db PATH] <package> <dependency>
vwhy --top [--json] [--sort unique|own] [--limit N] [--db PATH] <path>
vwhy --tui [--db PATH] <path>
```

- `<package>` and `--top`'s `<path>` are store paths, or anything that links
  into the store: `/run/current-system`, a profile link, `./result`, a file
  inside a store path.
- `<dependency>` is a store path (taken as written, so it need not exist
  here), another path (followed into the store), or a **name**: a base name
  (`glibc-2.44-57`), a hash part, or a package name as vdiff parses it
  (`glibc` matches `glibc-2.44-57` and `glibc-2.44-57-bin`). A name answers for
  every closure member it matches, shortest chain first.
- `--db` reads another store database (default `/nix/var/nix/db/db.sqlite`,
  opened read-only: no daemon, no root).
- Exit codes are id_effect_cli's: 0; 1 on any error (usage, a path that is not
  valid, a package that does not depend on the dependency, an unreadable
  database); 101 on a bug; 130 on Ctrl-C.

## The chain

`vwhy <package> <dependency>` prints what `nix why-depends` prints, without
its colour codes:

```
/nix/store/…-nixos-system-drakkar-26.11.20261120.9996594
└───/nix/store/…-system-path
    └───/nix/store/…-assay-0.3.0
        └───/nix/store/…-glibc-2.42-67
```

It is a shortest chain: from the package, step to the reference nearest the
dependency (by a breadth-first walk of the reversed references), the first in
path order on a tie, which is the order nix breaks ties in. A package is its
own chain, through its self-reference when it has one, as in nix.

`--all` prints every edge on a path from the package to the dependency as
`nix why-depends --all` does (each node expanded under its first line only),
then the number of distinct chains, which a system closure can put in the
millions.

Deliberate differences from nix:

- A package that does not depend on the dependency is an error (exit 1),
  where nix prints the same sentence and exits 0.
- `--all` orders siblings by their true distance to the dependency. nix runs
  its "Dijkstra" over a `std::priority_queue<Node *>`, which orders by pointer
  and queues each node once, so some of its distances are longer than the
  shortest and some of its siblings come later. The nodes and edges are the
  same; on drakkar 6 of 20 `--all` trees differ in order only (see GH-182's
  baseline).
- No `--precise` (the file and offset of each reference).

## `--top`

The closure's members ranked by **unique size**: a member's own narSize plus
that of every member it dominates, that is every member each of whose chains
from the root passes through it. It is what dropping that member would take
out of the closure, which nix-tree's "added size" approximates. `--sort own`
ranks by narSize instead. `--limit` rows (default 25; 0 for every member). The
root is not ranked; its line gives the closure's path count and total size.

```
/nix/store/…-nixos-system-drakkar-…: 3652 paths, 34.7 GiB
    UNIQUE         OWN  PATH
  15.2 GiB    12.2 MiB  /nix/store/…-system-path
   1.6 GiB     1.0 GiB  /nix/store/…-rustc-1.99.1
```

The dominators are Cooper, Harvey and Kennedy's iteration over a reverse
postorder. Sizes are binary units, one decimal, rounded down.

## `--tui`

fzf over every member, ranked by unique size, with the chain from the root as
the preview (vwhy again, on the highlighted path). Enter prints the chosen
path's chain; Esc prints nothing. fzf is `$VWHY_FZF`, or `fzf` on PATH (the
cli-core profile installs it).

## `--json` (schema 1)

Stable: a change a reader could notice bumps `schema`.

```json
{
  "schema": 1,
  "package": "/nix/store/…-nixos-system-…",
  "query": "glibc",
  "dependencies": [
    {
      "path": "/nix/store/…-glibc-2.44-57",
      "chain": ["/nix/store/…-nixos-system-…", "/nix/store/…-glibc-2.44-57"],
      "chainCount": 1140229,
      "edges": [["/nix/store/…-nixos-system-…", "/nix/store/…-glibc-2.44-57"]]
    }
  ]
}
```

`chainCount` (saturating at 2^64 − 1) and `edges` (every `[referrer,
reference]` of `--all`'s tree, in its order) are there with `--all` only.

```json
{
  "schema": 1,
  "root": "/nix/store/…-nixos-system-…",
  "paths": 3652,
  "narSize": 37258896448,
  "sort": "unique",
  "top": [
    { "path": "/nix/store/…-system-path", "name": "system-path", "version": null, "narSize": 12800000, "uniqueSize": 16320000000 }
  ]
}
```

`name` and `version` are vdiff's split of the store name (`version` is null
when there is none). Sizes are bytes.

## How it reads the store

A closure is two recursive queries over `ValidPaths` and `Refs`: its members
(id, path, narSize) and the references out of them. They are independent, so
they run as two id_effect fibers (`zip_par`), each a blocking read in
`suspend` on its own read-only connection. The reference query uses a CROSS
JOIN so SQLite walks `Refs` by its key; with a plain JOIN its planner scans
the whole table (150 ms on a 175k-path store, for any closure). Everything
after the reads is plain functions over the graph (`graph.vlt`).

The program runs under id_effect_cli's `run_main`, as a child fiber of the
root, since the parallel reads want the runtime's executor.

## Tests

`cargo test` runs the graph cases (chains, ties, self-references, the `--all`
tree, chain counts, dominators and unique sizes over small fixtures), the
rendering (text against nix's form, both JSON documents), argument parsing and
the usage errors, the store queries against an in-memory database with Nix's
schema (and that the reference query never scans `Refs`), and, where this
machine has a store database and `/run/current-system`, the graph against
nix-store-core's `closure` and `references` and the program end to end. In the
build sandbox those last pass vacuously.
