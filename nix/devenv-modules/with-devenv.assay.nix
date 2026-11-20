# Colocated suite for nix/devenv-modules/with-devenv.nix.
#
# Every git hook and moon task in this repo runs through `config.local.withDevenv`, so what
# that wrapper exports is what every hook sees. The module is evaluated with feature-eval's
# stubs and a probe env; claims read the generated wrapper script and enterShell fragment,
# which are the artifacts (generated text, not this module's source).
#
# The exclusions matter more than the inclusions: dotenv values would be baked into the
# world-readable store, and DEVENV_TASKS/DEVENV_TASK_FILE serialise the task graph that
# references this wrapper — infinite recursion at eval.
let
  assay = import ./lib/assay.nix;
  h = import ./lib/feature-eval.nix {};
  inherit (h) lib pkgs;

  probe = {lib, ...}: {
    packages = [pkgs.hello];
    env = {
      PLAIN = "plain-value";
      NUM = 7;
      SPACED = "a b";
      LISTY = ["not" "scalar"];
      DEVENV_TASKS = "tasks-json";
      DEVENV_TASK_FILE = "/tasks.json";
      SECRET = "s3cret";
    };
    dotenv.resolved.SECRET = "s3cret";
    enterShell = lib.mkAfter "echo late-hook";
  };
  cfg = (h.evalModule ./with-devenv.nix probe).config;
  wrapper = cfg.local.withDevenv;
  script = wrapper.text;

  exported = lib.remove "PATH" (lib.concatMap (l: let
    m = builtins.match "export ([A-Za-z_][A-Za-z0-9_]*)=.*" l;
  in
    if m == null
    then []
    else m) (lib.splitString "\n" script));
  # Store paths carry string context, which regex builtins refuse; the text is all we compare.
  plain = builtins.unsafeDiscardStringContext;
  has = needle: s: lib.hasInfix (plain needle) (plain s);
  hasSuffix = suffix: s: lib.hasSuffix suffix (plain s);
  # Offset of the first occurrence of `needle` in `s`, or -1.
  pos = needle: s: let
    parts = builtins.split (lib.escapeRegex needle) (plain s);
  in
    if builtins.length parts == 1
    then -1
    else builtins.stringLength (builtins.head parts);
  # Both present, `a` first.
  before = a: b: s: pos a s >= 0 && pos b s > pos a s;
  snapshotSource = ". \"$snapshot\"";
  dotenvSource = ". \"\${DEVENV_ROOT:-.}/.env\"";
in
  assay.suite "with-devenv" {
    wrapperIsWithDevenv = assay.eq wrapper.name "with-devenv";
    # Hooks rely on this being the one wrapper; a second definition must be an eval error.
    wrapperIsReadOnly =
      assay.throws
      "let h = import ${toString ./lib/feature-eval.nix} {}; in (h.evalModule ${toString ./with-devenv.nix} {local.withDevenv = h.pkgs.hello;}).config.local.withDevenv.name"
      "read-only";

    # (1) config.packages on PATH, config.env exported.
    packagesOnPath = assay.eq (has "${pkgs.hello}/bin" script) true;
    exportsScalarEnvOnly = assay.eq exported ["NUM" "PLAIN" "SPACED"];
    escapesValues = assay.eq (has "export SPACED='a b'" script) true;
    neverBakesDotenvValues = assay.eq (has "s3cret" script) false;
    neverExportsTaskGraph = assay.eq (has "tasks-json" script) false;

    # (2) then the snapshot, (3) then .env — later sources win, so .env overrides the snapshot.
    sourcesSnapshot = assay.eq (pos snapshotSource script >= 0) true;
    dotenvAfterSnapshot = assay.eq (before snapshotSource dotenvSource script) true;
    execsArguments = assay.eq (hasSuffix "exec \"$@\"\n\n" script) true;

    # enterShell links the wrapper and takes the snapshot, last of all enterShell work — even
    # after a fragment another module appends with mkAfter.
    linksWrapper = assay.eq (has "ln -sfn ${wrapper}/bin/with-devenv \"$DEVENV_DOTFILE/with-devenv\"" cfg.enterShell) true;
    snapshotRunsLast = assay.eq (before "echo late-hook" "export -p" cfg.enterShell) true;
    # The snapshot holds every exported variable: owner-only, and swapped in atomically.
    snapshotOwnerOnly = assay.eq (before "umask 077" "export -p" cfg.enterShell) true;
    snapshotAtomic = assay.eq (has "mv -f \"$DEVENV_DOTFILE/with-devenv.env.tmp\" \"$DEVENV_DOTFILE/with-devenv.env\"" cfg.enterShell) true;
    # A hook runs inside git, which sets GIT_DIR/GIT_INDEX_FILE; replaying the shell's values
    # would point it at the wrong index.
    snapshotDropsGitVars = assay.eq (has "|GIT_[A-Z_]+|" cfg.enterShell) true;
    snapshotDropsSessionVars = assay.eq (has "|SSH_[A-Z_]+|" cfg.enterShell) true;
  }
