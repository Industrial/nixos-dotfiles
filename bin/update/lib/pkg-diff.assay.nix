# Colocated suite for bin/update/lib/pkg-diff.nix -- the per-host package diff that the
# update-flake-lock workflow writes into every lock-bump PR body. Every claim calls the
# real functions on literal data; nothing here regexes the source.
let
  assay = import ./../../../common/assay/default.nix;
  d = import ./pkg-diff.nix;

  # Stand-ins for evaluated derivations: only the attributes facts/pkgEntry read.
  cfg = pkgs: {
    system.nixos.version = "25.11.20261101.abcdef0";
    boot.kernelPackages.kernel.version = "6.12.1";
    environment.systemPackages = pkgs;
  };
  firefox = v: {
    pname = "firefox";
    version = v;
    name = "firefox-${v}";
  };
  script = {name = "update-helper";}; # writeShellScriptBin-style: no pname/version

  old = d.facts (cfg [(firefox "128.0") script {name = "htop-3.3.0";} {name = "gone-1.0";}]);
  new =
    d.facts (cfg [(firefox "129.0") script {name = "htop-3.3.0";} {name = "fresh-2.0";}])
    // {kernel = "6.12.5";};
  diff = d.compare old new;

  lock = revs: {
    root = "root";
    nodes = {
      root.inputs = {
        nixpkgs = "nixpkgs_2";
        local = "local";
        follower = ["nixpkgs"];
      };
      nixpkgs_2.locked = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        rev = revs.nixpkgs;
      };
      local.locked = {
        type = "path";
        narHash = revs.local;
      };
    };
  };
  lockOld = lock {
    nixpkgs = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    local = "sha256-same";
  };
  lockNew = lock {
    nixpkgs = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    local = "sha256-same";
  };
  inputs = d.inputChanges lockOld lockNew;

  has = pattern: s: builtins.match pattern s != null;
  hostMd = d.renderHost "drakkar" 100 diff;
in
  assay.suite "update-pkg-diff" {
    # pname/version wins; parseDrvName is the fallback; a bare name has an empty version.
    entryFromPnameVersion = assay.eq (d.pkgEntry (firefox "1.0")) {
      name = "firefox";
      version = "1.0";
    };
    entryFromParsedName = assay.eq (d.pkgEntry {name = "htop-3.3.0";}) {
      name = "htop";
      version = "3.3.0";
    };
    entryWithoutVersion = assay.eq (d.pkgEntry script) {
      name = "update-helper";
      version = "";
    };

    # Two versions of one pname collapse into one sorted entry, not two rows.
    collapsesDuplicates = assay.eq (d.toVersionMap [
      {
        name = "python3";
        version = "3.13.1";
      }
      {
        name = "python3";
        version = "3.12.8";
      }
      {
        name = "python3";
        version = "3.13.1";
      }
    ]) {python3 = "3.12.8, 3.13.1";};

    changedIsExactlyTheVersionMove = assay.eq diff.changed [
      {
        name = "firefox";
        from = "128.0";
        to = "129.0";
      }
    ];
    addedPackage = assay.eq diff.added [
      {
        name = "fresh";
        version = "2.0";
      }
    ];
    removedPackage = assay.eq diff.removed [
      {
        name = "gone";
        version = "1.0";
      }
    ];
    kernelMoveIsReported = assay.eq diff.kernel {
      from = "6.12.1";
      to = "6.12.5";
    };
    nonEmptyDiff = assay.eq (d.isEmpty diff) false;
    identicalTreesAreEmpty = assay.eq (d.isEmpty (d.compare old old)) true;

    # Only the github input moved; the unchanged path input and the `follows` list are
    # not reported, and the moved one carries a compare link.
    inputChangesOnlyMoved = assay.eq (map (c: c.name) inputs) ["nixpkgs"];
    inputCompareLink =
      assay.eq (builtins.head inputs).compare
      "https://github.com/NixOS/nixpkgs/compare/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa...bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    noInputsMoved = assay.eq (d.inputChanges lockOld lockOld) [];
    renderNoInputs = assay.eq (d.renderInputs []) "No root flake input moved.\n";
    renderInputsRow = assay.eq (has ".*[|] `nixpkgs` [|] `aaaaaaaaaaaa` [|] `bbbbbbbbbbbb` [|] [[]compare[]].*" (d.renderInputs inputs)) true;

    # Rendered markdown names the host, the kernel move, and each kind of row.
    renderHeading = assay.eq (has "### drakkar\n.*" hostMd) true;
    renderKernel = assay.eq (has ".*- Kernel: `6.12.1` -> `6.12.5`.*" hostMd) true;
    renderNixosUnchanged = assay.eq (has ".*- NixOS: `25.11.20261101.abcdef0` \\(unchanged\\).*" hostMd) true;
    renderCounts = assay.eq (has ".*1 changed, 1 added, 1 removed.*" hostMd) true;
    renderChangedRow = assay.eq (has ".*[|] `firefox` [|] `128.0` [|] `129.0` [|].*" hostMd) true;
    renderAddedRow = assay.eq (has ".*[|] `fresh` [|] \\(new\\) [|] `2.0` [|].*" hostMd) true;
    renderRemovedRow = assay.eq (has ".*[|] `gone` [|] `1.0` [|] \\(removed\\) [|].*" hostMd) true;

    # The row cap elides, says so, and keeps the full totals.
    renderLimitElides = assay.eq (has ".*2 more rows elided.*" (d.renderHost "drakkar" 1 diff)) true;
    renderLimitKeepsTotals = assay.eq (has ".*1 changed, 1 added, 1 removed.*" (d.renderHost "drakkar" 1 diff)) true;
    renderEmptyHasNoTable = assay.eq (has ".*<details>.*" (d.renderHost "drakkar" 100 (d.compare old old))) false;
  }
