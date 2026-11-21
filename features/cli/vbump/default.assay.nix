# Colocated suite for features/cli/vbump: the package it installs is the
# rust/tools/vbump crate, built from the pinned nixpkgs; and vbump's take-over of the
# lock bumps (GH-189), with its one rollback switch.
#
# The workflow's selector is not regex-matched as text and left there: each job's `if:`
# is parsed into its selector expression and the job value it runs for, and the
# expression is evaluated the way GitHub does (`a || b || 'c'`: the first non-empty
# term), for each case a scheduled or a dispatched run can present.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  # Stubbed pkgs: which package file the feature calls, and with what.
  stub = {callPackage = path: args: {inherit path args;};};
  stubbed = (import ./default.nix {pkgs = stub;}).environment.systemPackages;

  # The real module, evaluated.
  cfg = nixos.eval {modules = [./default.nix];};
  vbumps = builtins.filter (p: (p.pname or "") == "vbump") cfg.environment.systemPackages;

  # The update workflow's jobs gated on the updater: selector expression and the value
  # each runs for.
  workflow = builtins.readFile ./../../../.github/workflows/update-flake-lock.yml;
  gate = "    if: github\\.ref == 'refs/heads/main' && \\((.*)\\) == '([a-z]+)'";
  gated =
    map (l: let
      m = builtins.match gate l;
    in {
      selector = builtins.elemAt m 0;
      runsFor = builtins.elemAt m 1;
    })
    (builtins.filter (l: builtins.match gate l != null) (lib.splitString "\n" workflow));

  # GitHub's `||`: the first term that is set and not empty; 'x' is a literal.
  value = ctx: term: let
    literal = builtins.match "'(.*)'" term;
  in
    if literal != null
    then builtins.head literal
    else ctx.${term} or "";
  select = ctx: selector:
    lib.findFirst (v: v != "") "" (map (value ctx) (lib.splitString " || " selector));
  # The gated jobs a run with these inputs and variables starts.
  runs = ctx: map (g: g.runsFor) (builtins.filter (g: select ctx g.selector == g.runsFor) gated);

  byHand = builtins.readFile ./../../../bin/update/flake;
in
  assay.suite "cli-vbump" {
    installsTheCrate = assay.eq (map (p: p.path) stubbed) [../../../rust/tools/vbump/default.nix];
    noOverrides = assay.eq (map (p: p.args) stubbed) [{}];

    inSystemPackages = assay.eq (builtins.length vbumps) 1;
    providesTheBinary = assay.eq (map (p: p.meta.mainProgram) vbumps) ["vbump"];

    # Two gated jobs (vbump and the legacy lock job), one selector between them.
    oneSelectorTwoJobs =
      assay.eq [(builtins.length gated) (lib.unique (map (g: g.selector) gated)) (lib.sort (a: b: a < b) (map (g: g.runsFor) gated))]
      [2 ["inputs.updater || vars.FLAKE_LOCK_UPDATER || 'vbump'"] ["legacy" "vbump"]];

    # Take-over: a scheduled run (no inputs, no variable) is vbump, and only vbump.
    scheduledRunIsVbump = assay.eq (runs {}) ["vbump"];
    emptyVariableIsVbump = assay.eq (runs {"vars.FLAKE_LOCK_UPDATER" = "";}) ["vbump"];

    # Rollback: the one variable restores the old single-PR job, and only it.
    variableRollsBack = assay.eq (runs {"vars.FLAKE_LOCK_UPDATER" = "legacy";}) ["legacy"];
    # A dispatch picks either, whatever the variable says.
    dispatchPicksLegacy = assay.eq (runs {"inputs.updater" = "legacy";}) ["legacy"];
    dispatchOverridesTheVariable = assay.eq (runs {
      "inputs.updater" = "vbump";
      "vars.FLAKE_LOCK_UPDATER" = "legacy";
    }) ["vbump"];
    dispatchDefaultIsVbump =
      assay.eq (lib.hasInfix "        type: choice\n        options: [vbump, legacy]\n        default: vbump\n" workflow) true;

    # By hand: bin/update/flake runs vbump against origin/main whenever vbump is
    # installed; with this feature off (no vbump on PATH) or UPDATE_LEGACY=1 it is the
    # old all-inputs `nix flake update`.
    # The token: minted per run from the vbump app, pinned by commit, only when both
    # secrets exist; the push and gh use it first and fall back to today's tokens.
    appTokenPinned = assay.eq (lib.hasInfix "uses: actions/create-github-app-token@f418cff399f7aef4c2f0ad47e25ca7a6abbdd6fc # v3.4.0\n" workflow) true;
    appTokenOnlyWithBothSecrets = assay.eq [
      (lib.hasInfix "HAS_APP: \${{ secrets.VBUMP_APP_ID != '' && secrets.VBUMP_APP_PRIVATE_KEY != '' }}\n" workflow)
      (lib.hasInfix "        id: app\n        if: env.HAS_APP == 'true'\n" workflow)
      (lib.hasInfix "        if: env.HAS_APP != 'true'\n" workflow)
    ] [true true true];
    appTokenFirstForPushAndGh =
      assay.eq (builtins.length (lib.splitString "\${{ steps.app.outputs.token || secrets.FLAKE_LOCK_UPDATE_TOKEN || github.token }}" workflow)) 3;

    byHandRunsVbump = assay.eq (lib.hasInfix "\n  exec vbump run --rev origin/main \"$@\"\n" byHand) true;
    byHandFallsBack = assay.eq [
      (lib.hasInfix "if [ \"\${UPDATE_LEGACY:-0}\" != 1 ] && command -v vbump >/dev/null 2>&1; then" byHand)
      (lib.hasInfix "\nnix --experimental-features \"nix-command flakes\" flake update\n" byHand)
    ] [true true];
  }
