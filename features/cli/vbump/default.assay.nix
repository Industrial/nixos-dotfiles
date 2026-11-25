# Colocated suite for features/cli/vbump: the package it installs is the
# rust/tools/vbump crate, built from the pinned nixpkgs; vbump is the only flake.lock
# updater (GH-247), and every PR it opens arms auto-merge.
#
# "Only one lock updater" is checked over what exists, not over a list: every workflow
# under .github/workflows and every script under bin/ is read, and the ones that update
# flake.lock (vbump, `nix flake update`, the update-flake-lock action) are named. The
# answer has to be vbump.yml (and bin/update/flake, which only runs vbump).
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

  workflows = ./../../../.github/workflows;
  workflow = builtins.readFile (workflows + "/vbump.yml");
  bin = ./../../../bin;

  # What updates flake.lock, as text: vbump's run, C++ Nix's whole-lock update, the
  # DeterminateSystems action the legacy workflow used.
  updatesTheLock = text:
    builtins.any (m: lib.hasInfix m text) [
      "vbump \"\${args[@]}\""
      "exec vbump run"
      "flake update\n"
      "flake update;"
      "flake update &&"
      "update-flake-lock@"
    ];
  workflowFiles = builtins.filter (n: lib.hasSuffix ".yml" n || lib.hasSuffix ".yaml" n) (builtins.attrNames (builtins.readDir workflows));
  updaterWorkflows = builtins.filter (n: updatesTheLock (builtins.readFile (workflows + "/${n}"))) workflowFiles;
  binFiles = lib.filesystem.listFilesRecursive bin;
  updaterScripts = map (p: lib.removePrefix (toString bin + "/") (toString p)) (builtins.filter (p: updatesTheLock (builtins.readFile p)) binFiles);

  byHand = builtins.readFile ./../../../bin/update/flake;
  runbook = builtins.readFile ./../../../docs/runbooks/updates.md;
  forge = builtins.readFile ./../../../rust/tools/vbump/src/forge.vlt;

  # The rollback: the old workflow and script, restored from the last commit that had them.
  rollback = "git checkout 056a7031988ab79b639c9d2c0b5fddadbadf22e0 -- .github/workflows/update-flake-lock.yml bin/update/flake";
  appToken = "\${{ steps.app.outputs.token || github.token }}";
in
  assay.suite "cli-vbump" {
    installsTheCrate = assay.eq (map (p: p.path) stubbed) [../../../rust/tools/vbump/default.nix];
    noOverrides = assay.eq (map (p: p.args) stubbed) [{}];

    inSystemPackages = assay.eq (builtins.length vbumps) 1;
    providesTheBinary = assay.eq (map (p: p.meta.mainProgram) vbumps) ["vbump"];

    # Take-over (GH-247): the whole-lock workflow is gone, and exactly one workflow
    # updates the lock: vbump's, on its schedule.
    legacyWorkflowDeleted = assay.eq (builtins.pathExists (workflows + "/update-flake-lock.yml")) false;
    exactlyOneLockUpdater = assay.eq updaterWorkflows ["vbump.yml"];
    vbumpRunsOnASchedule = assay.eq [
      (lib.hasInfix "on:\n  schedule:\n    # Mondays 03:23 UTC: off the hour, and a full week of upstream churn per bump.\n    - cron: '23 3 * * 1'\n" workflow)
      (lib.hasInfix "    if: github.ref == 'refs/heads/main'\n" workflow)
    ] [true true];
    # No selector left: one job, and no legacy job, variable or token.
    oneJob = assay.eq (builtins.filter (l: builtins.match "  [a-z-]+:" l != null) (lib.splitString "\n" (lib.last (lib.splitString "\njobs:\n" workflow)))) ["  vbump:"];
    noLegacySwitch = assay.eq (map (m: lib.hasInfix m workflow) ["FLAKE_LOCK_UPDATER" "inputs.updater" "update-flake-lock@" "FLAKE_LOCK_UPDATE_TOKEN"]) [false false false false];
    # No script under bin/ updates the lock on its own; bin/update/flake only runs vbump.
    onlyTheByHandVbump = assay.eq updaterScripts ["update/flake"];
    byHandRunsVbump = assay.eq (lib.hasInfix "\nexec vbump run --rev origin/main \"$@\"\n" byHand) true;
    byHandHasNoFallback = assay.eq (map (m: lib.hasInfix m byHand) ["UPDATE_LEGACY" "flake update"]) [false false];

    # Auto-merge (GH-247): the scheduled run passes --auto-merge, and vbump arms it as a
    # squash merge; main's required `ci / all-green` is the gate it waits for.
    scheduledRunArmsAutoMerge =
      assay.eq (lib.hasInfix "--committer \"$COMMITTER\" --auto-merge)\n" workflow) true;
    # GH-314: through GraphQL enablePullRequestAutoMerge, which refuses a clean PR, and
    # never `gh pr merge` (on a clean PR, `--auto` merges on the spot: #308).
    vbumpArmsSquashAutoMerge = assay.eq [
      (lib.hasInfix "enablePullRequestAutoMerge(input: {pullRequestId: $id, mergeMethod: SQUASH})" forge)
      (lib.hasInfix "arm_args node = .to_vec ([.to_string \"api\", .to_string \"graphql\"" forge)
      (lib.hasInfix "  if l.auto_merge\n    (armed (&l) (&url))?\n" forge)
    ] [true true true];
    vbumpNeverMergesDirectly = assay.eq (lib.hasInfix "\"pr\", \"merge\"" forge || lib.hasInfix ".to_string \"merge\"" forge) false;

    # The token: minted per run from the vbump app, pinned by commit, only when both
    # secrets exist; the push and gh (and so the auto-merge) use it first.
    appTokenPinned = assay.eq (lib.hasInfix "uses: actions/create-github-app-token@f418cff399f7aef4c2f0ad47e25ca7a6abbdd6fc # v3.4.0\n" workflow) true;
    appTokenOnlyWithBothSecrets = assay.eq [
      (lib.hasInfix "HAS_APP: \${{ secrets.VBUMP_APP_ID != '' && secrets.VBUMP_APP_PRIVATE_KEY != '' }}\n" workflow)
      (lib.hasInfix "        id: app\n        if: env.HAS_APP == 'true'\n" workflow)
      (lib.hasInfix "        if: env.HAS_APP != 'true'\n" workflow)
    ] [true true true];
    appTokenFirstForPushAndGh = assay.eq (builtins.length (lib.splitString appToken workflow)) 3;
    # Enough for auto-merge: contents and pull requests write.
    appTokenCanAutoMerge = assay.eq [
      (lib.hasInfix "          permission-contents: write\n" workflow)
      (lib.hasInfix "          permission-pull-requests: write\n" workflow)
    ] [true true];

    # The one rollback, written where an operator looks (the runbook) and in the
    # workflow's header, as the same command.
    rollbackDocumented = assay.eq [(lib.hasInfix rollback runbook) (lib.hasInfix rollback workflow)] [true true];
  }
