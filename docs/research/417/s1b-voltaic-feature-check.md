# #417 S1b: Voltaic 0.3.0 feature check for a typed module system

Stage S1b of #417 asks what Voltaic 0.3.0 can and cannot express for a NixOS-style module system:
typed options with merging and priorities, open extensibility, records with defaults, cross-module
reads with cycle detection, pure evaluation, typed package handles and `.drv` emission. It also
asks for compile latency to be measured. The answers come from spikes in
[`rust/spikes/voltaic-modules/`](../../../rust/spikes/voltaic-modules/), which compile, pass their
tests and are clippy-clean (`-D warnings`). Measured 2026-11-27 on drakkar.

## The one fact that frames everything

Voltaic is a **type-free surface for Rust**. Every construct lowers to Rust from the source text
alone (doc 03 §2), there is no Voltaic type checker (declined, `docs/DECLINED.md`), and there is
no runtime or standard library of its own. So "can Voltaic express X" comes down to two
questions. Can Rust express X? If so, does Voltaic's surface reach that Rust? Semantics such as
laziness, open records and purity are never Voltaic language features. They are Rust library
patterns written in Voltaic syntax. Nothing in #417 needs a language feature that Rust lacks.
What follows records where the surface reaches and where it trips.

## Feature matrix

| #417 needs | Verdict | How, in the spike |
|---|---|---|
| Typed option slots: merge strategy, priority, default, docs | **Supported** | `modsys/src/option.vlt`. `OptionDecl<T> { path, doc, default: Option<T>, strategy: Strategy<T> }`, `Def<T> { origin, priority, value }`, and NixOS priorities (`FORCE` 50, `NORMAL` 100, `DEFAULT` 1000; lower wins). `Strategy` is `Unique` (equal or conflict) or `Fold(Box<dyn Fn(T, T) -> T>)` (lists concatenate, bools `any`). A conflict names every module and the priority. A definition of the wrong type is a rustc error. Generic records work because Voltaic infers `<T>` from lowercase type variables in field types |
| Open extensibility (modules define options declared elsewhere) | **Workaround (library pattern)** | `modsys/src/eval.vlt`. Rust has no open records, so there is no central `Config` struct. The declaring module exports a typed `Key<T>` constant. The registry stores each slot type-erased (`Box<dyn Any>`) and every access goes back through `Key<T>`. **rustc catches** a wrong type and a definition of an undeclared option (there is no key to import). **The evaluator catches at run time** two modules declaring one path |
| Records with defaults | **Supported, without per-field defaults** | `deriving (Default)` plus the spread `R { a = 1, ...R::default () }` (struct update, since 0.2.1). A preset is a named constructor (`Unit::service ()`). Default *arguments* are declined (doc 03 §8.7), and per-field `= value` defaults in `data` do not exist. Either write `instance Default` by hand or use a derive template |
| Cross-module reads: lazy fixpoint | **Workaround (library pattern)** | `modsys/src/lazy.vlt`. Thunks are `Box<dyn Fn(&Fix<V>) -> Result<V, _>>`, memoised in a `RefCell`, with a forcing stack. A re-entered attribute is reported as its chain: `infinite recursion: a -> b -> a`. Voltaic needs no laziness of its own |
| Cross-module reads: declared read/write DAG | **Supported (library)** | `modsys/src/eval.vlt`. Each `Module` lists `reads` and `writes`. Writers run before readers in a topological order, and a read or write outside the declaration is refused. A cycle is reported through modules **and** options: `evaluation cycle: a -[x]-> b -[y]-> a` |
| Evaluation in an id_effect env with no IO capability | **Partial: R covers capabilities, not ambient IO** | `modsys/src/pure.vlt`. `evaluated : … -> Effect<A, EvalError, HNil>`. A pinned fetch is `Effect<_, _, HCons<Fetch, HNil>>`, and putting one inside the `HNil` evaluation is a rustc error (`expected Effect<_, _, HNil>, found Effect<_, _, HCons<Fetch, HNil>>`, probed). **But** `suspend (\-> std::fs::read_to_string …)` type-checks at `R = HNil` (probed), and vcache's `load_signer` does exactly this. `R` tracks what is *asked for*, not ambient authority. The fence is `host/clippy.toml`: `disallowed-methods` / `disallowed-types` over std's fs, process, net, env and clock, which caught the probe inside the `include!`d generated code. Voltaic's own `io` row does not see these calls (Industrial/voltaic#19) |
| Typed package handles from a pinned index | **Supported via codegen** | `modsys/src/index.vlt` (`gen-index`). Run once per lock bump, it reads the `.drv` closure, computes each package's modulo hash and writes `host/src/pkgs.vlt` as `export const BASH : Pkg = Pkg { attr, drv, out, modulo }`. A package missing from the index is a compile error, and emitting a derivation reads no file |
| Emitting ATerm `.drv` | **Supported, byte-identical to Nix** | `modsys/src/drv.vlt`: ATerm `unparse`, `hashDerivationModulo` (input `.drv`s replaced by their modulo hashes, outputs and their env entries blanked), `makeStorePath` (output paths) and `makeTextPath` (the `.drv` path). `host/src/oracle.vlt` asserts that the host's toplevel equals `oracle.nix`'s `derivation { … }` on the pinned nixpkgs (`oracle.assay.nix` checks the Nix side), with path, out path and text all byte-for-byte: `/nix/store/4aadlf2x…-s1b-hello.drv`. It builds on nix-store-core's `Derivation`, `digest` and `nixbase32` |

What the host spike exercises end to end (`host/src/{modules,host,toplevel}.vlt`):

- `networking` and `environment` declare options and `hello` declares its own.
- `hello` **reads** `networking.hostName` to default its greeting and **writes** bash into
  `environment.systemPackages`.
- The profile sets `hostName` at `mkDefault`. The host overrides it at 100 and forces the
  greeting at 50.
- The toplevel derivation is emitted from the merged values.

The 14 tests cover priorities, `mkForce`, conflicts, list folds, defaults, DAG order, undeclared
reads and writes, both cycle reports, the `HNil` evaluation, the `Fetch` capability with a stub,
and the oracle.

## Escape hatches, and which ones were needed

| Hatch | Used? |
|---|---|
| `rust """ … """` verbatim items | **No.** Everything is Voltaic |
| Verbatim macro bodies (`effect!`, `vec![…]`, `assert_eq!`) | Yes: `effect!` for the `~Fetch` read, and `vec![…]` for lists of non-`Clone` values |
| `given <…>` verbatim binders | Yes: every `'static` / multi-bound generic (`given <T: Clone + PartialEq + Debug + 'static>`) and every `fn(…)` pointer type in a signature |
| Type ascription `x : T` instead of a turbofish | Yes: `downcast_ref ()` / `downcast_mut ()` / `collect` |
| clippy allows on emitted code | `assign_op_pattern` (no `^=`), `just_underscores_and_digits`, `redundant_closure`, `type_complexity` |
| clippy `disallowed-methods` / `disallowed-types` | Yes: the purity fence. It must be denied in CI for configuration crates. Note: these spikes live under `rust/spikes/` and are **not** run by `bin/ci/cargo-standalone`, which covers only `rust/tools/*` |

## Voltaic gaps found (none blocks #417)

Every gap below had a workaround in the spike. Filed on Industrial/voltaic and put on board 3:

- **Industrial/voltaic#18 (bug): `voltaic fmt` changes meaning.**
  - It uppercases a `data` field's type variable (`value t` becomes `value T`). The struct then
    loses its generic and stops compiling.
  - It re-indents a guard arm's block body into an inconsistent dedent that no longer parses.
  - Every generic record in the module system hits the first. **Do not run `voltaic fmt` on
    these files until #18 is fixed.** That is why the spike's `.vlt` files are hand-formatted,
    and why a `fmt --check` gate is not possible for them yet.
- **Industrial/voltaic#19 (enhancement): the `io` effect row does not see std's IO paths.**
  `voltaic sig` gives `prints : () ! io` for `println!` but an empty row for
  `std::fs::read_to_string` and `std::process::Command`. A closed path table plus a
  "require no `io`" check would put #417's purity rule into Voltaic, where today it sits in clippy.
- **Industrial/voltaic#20 (bug): surface papercuts.**
  - `fn(…)` pointer types fail to parse in `data` fields. In a signature without `given`, `fn`
    is taken for a type variable.
  - Generic type aliases (`type X<V> = …`) do not parse.
  - `(m.f) x` lowers to the method call `m.f(x)`.
  - There is no `^=`.
  - A nullary function passed as a value is called if it is defined in the same file, but not if
    it is imported.

Also hit and already known: `module` is reserved, `?` binds to the last atom, and there are no
tuple patterns in `for` heads or lambda parameters. Bodies need uppercase `T` where signatures use
lowercase `t`. `x.f ()` used as an argument needs its own parentheses. Plain `cargo build`
reports errors against `OUT_DIR/*.rs`. Use `voltaic cargo-check` to get `.vlt` locations.

## Compile latency

The risk named in #417 is that a config change costs a rustc build. These figures time edit to
binary: `sed` one value in `host/src/host.vlt`, then `cargo build -p host`. The machine is
drakkar (32 threads), shared with other sessions, so read the spread as noise.

| What | Debug | Release |
|---|---|---|
| Clean build of the whole spike workspace (id_effect, nix-store-core with bundled SQLite, voltaic-driver) | 17.1 s | 77.7 s |
| No-op build | 0.22 s | — |
| **Host config edit → binary** (spike host, 5 modules) | **1.8–1.9 s** (+ run: 1.8–3.1 s) | **1.9–2.5 s** |
| Host config edit → `cargo check` | 0.23–0.27 s | — |
| Library (`modsys`) edit → rebuild lib + host | 4.7–5.7 s | — |
| Voltaic transpile of `host.vlt` alone | 10 ms | — |
| Running the evaluation and emission | — | 5–10 ms |

Scale probe (`.tmp/s1b-scale.sh`, not committed). A synthetic module declares and defines N
options of mixed types (`String`, `bool` with `any`, `u32`), all in **one** declaring function and
one defining function, and joins the host:

| N options | `.vlt` lines | Edit → debug binary | Edit → release binary |
|---|---|---|---|
| 300 | 2,123 | 2.4–2.6 s | 2.6–2.8 s |
| 1,000 | 7,023 | 1.1–1.6 s | 1.9–2.8 s |
| 3,000 | 21,023 | 5.8–6.1 s | 9.7–10.1 s |

The comparator is today's NixOS eval of a host toplevel `drvPath` with `--no-eval-cache`: muninn
25.1–25.7 s, drakkar 33.4 s (this run). S1's census measured 20.7–24.0 s and **2.6–2.8 GB RSS**
per host (`.tmp/census/time-eval-*.txt`). S1 also counts **799 defined options** across the
fleet's union (`s1-option-census.md`). At N = 1,000 the Voltaic path is about 10× faster edit to
binary, and evaluating takes milliseconds.

Two caveats. First, cost is **superlinear in one function's size**: 3× the options at N = 3,000
cost about 4× the time, because one giant body stresses rustc and LLVM. Real module bodies must
stay small and spread across functions and crates, which is also the natural shape. Second, real
modules generate more than scalar values: systemd units, `/etc` trees and activation scripts.
S3 should re-measure with one real subtree.

## Recommendation: a Voltaic library plus a Voltaic surface, split into crates

"A Rust library plus a Voltaic surface" is the right shape. The owner's rule (Voltaic + id_effect
all the way) and the spike agree that the library is **written in Voltaic** too: the spike needed
no `rust """` hatch. Concretely:

1. **`modsys` (library crate, Voltaic):**
   - `Key<T>`, `OptionDecl<T>`, `Strategy<T>`, priorities, the type-erased `Registry`.
   - The DAG scheduler with cycle paths.
   - `evaluated` at `R = HNil`, and `Fetch` as the only IO capability.
   - This changes rarely: a library edit costs about 5 s.
2. **The `.drv` writer goes into nix-store-core.** `aterm`, `hash_modulo`, `store_path` and
   `drv_path` belong beside its ATerm parser (`drv.vlt`), with the oracle test as their golden.
   vbuild and nix-store-core then realise what the evaluator emits.
3. **A declared read/write DAG as the default, with the lazy fixpoint kept for self-reference.**
   - The DAG makes dependencies explicit. Modules on independent branches can evaluate in
     parallel, the order is deterministic, and a cycle names its options.
   - NixOS's implicit `config.*` reads become a module's `reads` list, which can be typed as
     `Key`s rather than strings in the real version.
   - The lazy `Fix` covers the few options that are genuinely defined in terms of themselves.
4. **`nixos-modules` crate(s), Voltaic:** option declarations and bodies for the subset the fleet
   uses (S1: 799 defined options, 505 upstream). One function per option group.
5. **A generated `pkgs` crate:** typed `Pkg` handles from the pinned index, regenerated per lock
   bump (`gen-index`, later in vbump). Generate only the attributes the fleet references, or one
   module per attribute prefix. Constants for all of nixpkgs (~120k attributes) are an unmeasured
   compile cost.
6. **One crate (or bin) per host:** the only thing a config change recompiles, at about 2 s edit
   to binary.
7. **Purity.** `R = HNil` for evaluation and `Fetch` for pinned fetches. The clippy
   disallowed-IO fence is denied in CI for crates 4–6, and the spike's `host/clippy.toml` is the
   template.
   - Residual hole: dependencies, `build.rs` and proc-macros are not linted. The module crates
     must therefore depend only on `modsys`, nix-store-core's pure parts and `pkgs`.
   - Long term: a Voltaic `io` row check (Industrial/voltaic#19).

### What not to do

- **No generated closed `Config` struct for now.** It would give static field access, but every
  option declared anywhere would have to land in one type. Declaration reflection is declined in
  Voltaic, so this would need a derive template or a codegen step. Revisit only if the runtime
  `Any` downcasts become a measured cost. They are not one now: evaluation runs in 5–10 ms.
- **Do not wait for Voltaic features.** None of #18–#20 blocks S2–S4.

## Reproducing

Run from a checkout (worktrees: call `bin/with-devenv` from the main checkout and `cd` inside):

```
bin/with-devenv bash -c 'cd rust/spikes/voltaic-modules && cargo test && cargo clippy --all-targets -- -D warnings'
bin/with-devenv bash -c 'assay run rust/spikes/voltaic-modules/oracle.assay.nix'   # Nix side of the oracle
bin/with-devenv bash -c 'cd rust/spikes/voltaic-modules && cargo run -q -p modsys --bin gen-index -- bash=<bash .drv>'
```

The latency scripts (`.tmp/s1b-latency.sh`, `.tmp/s1b-scale.sh`) were throwaway probes and are
described above rather than committed.
