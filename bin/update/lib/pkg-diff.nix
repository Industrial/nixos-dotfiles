# Pure functions behind bin/update/pkg-diff: what a flake.lock bump changes, per host,
# computed by EVALUATING both trees rather than building them.
#
# Why evaluate, not build: a real closure diff (`nix store diff-closures`, vdiff) needs both
# system closures realised. Three to four desktop/server closures per lock-bump PR do not
# fit a GitHub runner's disk or time budget, and this box is RAM-shared. The evaluated
# package set is the honest cheap proxy: it names every package in
# environment.systemPackages with its version, plus the kernel and NixOS release -- the
# lines an operator actually reviews. The exact built closure diff is produced on the
# host itself, after merge, by nixos-update-notifier (`vdiff --json`).
#
# Kept free of `pkgs` and of any IO so the colocated assay suite can call every function
# on literal data.
let
  # Same semantics as lib.concatMapStrings, without depending on nixpkgs.
  concatMap = f: xs: builtins.concatStringsSep "" (map f xs);

  # name -> version for one package-ish value. Derivations without pname/version (e.g.
  # writeShellScriptBin) fall back to parseDrvName on `name`.
  pkgEntry = p: let
    parsed = builtins.parseDrvName (p.name or "unknown");
  in {
    name = p.pname or parsed.name;
    version = p.version or parsed.version;
  };

  # A list of {name, version} -> attrset name -> "v1, v2" (several outputs or several
  # versions of the same pname collapse into one sorted, de-duplicated entry).
  toVersionMap = entries: let
    grouped = builtins.groupBy (e: e.name) entries;
    names = builtins.attrNames grouped;
    versionsOf = n: let
      vs = map (e: e.version) grouped.${n};
      uniq = builtins.attrNames (builtins.listToAttrs (map (v: {
          name = v;
          value = null;
        })
        vs));
    in
      builtins.concatStringsSep ", " uniq;
  in
    builtins.listToAttrs (map (n: {
        name = n;
        value = versionsOf n;
      })
      names);
in rec {
  inherit pkgEntry toVersionMap;

  # Everything the diff needs out of one evaluated NixOS `config`. Only this function
  # touches a real configuration; the rest works on its (JSON-able) result.
  facts = config: {
    nixos = config.system.nixos.version;
    kernel = config.boot.kernelPackages.kernel.version;
    packages = toVersionMap (map pkgEntry config.environment.systemPackages);
  };

  # facts -> facts -> structured diff. Sorted by package name throughout.
  compare = old: new: let
    oldNames = builtins.attrNames old.packages;
    newNames = builtins.attrNames new.packages;
    inOld = n: old.packages ? ${n};
    inNew = n: new.packages ? ${n};
  in {
    nixos = {
      from = old.nixos;
      to = new.nixos;
    };
    kernel = {
      from = old.kernel;
      to = new.kernel;
    };
    changed = map (n: {
      name = n;
      from = old.packages.${n};
      to = new.packages.${n};
    }) (builtins.filter (n: inNew n && old.packages.${n} != new.packages.${n}) oldNames);
    added = map (n: {
      name = n;
      version = new.packages.${n};
    }) (builtins.filter (n: !(inOld n)) newNames);
    removed = map (n: {
      name = n;
      version = old.packages.${n};
    }) (builtins.filter (n: !(inNew n)) oldNames);
  };

  isEmpty = d:
    d.changed == [] && d.added == [] && d.removed == [] && d.nixos.from == d.nixos.to && d.kernel.from == d.kernel.to;

  # Root inputs whose locked revision moved between two parsed flake.lock files.
  # `follows` inputs (list values) are skipped: they move with the input they follow.
  inputChanges = oldLock: newLock: let
    rootInputs = lock: lock.nodes.${lock.root or "root"}.inputs or {};
    nodeOf = lock: name: let
      ref = (rootInputs lock).${name};
    in
      if builtins.isString ref
      then lock.nodes.${ref}.locked or {}
      else null;
    revOf = locked:
      if locked == null
      then null
      else locked.rev or locked.narHash or null;
    names = builtins.sort builtins.lessThan (builtins.attrNames (rootInputs newLock));
    present = n: (rootInputs oldLock) ? ${n};
  in
    builtins.filter (c: c.from != c.to) (map (n: let
        o =
          if present n
          then nodeOf oldLock n
          else null;
        w = nodeOf newLock n;
      in {
        name = n;
        from = revOf o;
        to = revOf w;
        compare =
          if w != null && (w.type or "") == "github" && o != null && (o.rev or null) != null && (w.rev or null) != null
          then "https://github.com/${w.owner}/${w.repo}/compare/${o.rev}...${w.rev}"
          else null;
      })
      names);

  short = rev:
    if rev == null
    then "(none)"
    else builtins.substring 0 12 rev;

  renderInputs = changes:
    if changes == []
    then "No root flake input moved.\n"
    else
      "| Input | Before | After | Changes |\n|---|---|---|---|\n"
      + concatMap (c: "| `${c.name}` | `${short c.from}` | `${short c.to}` | ${
        if c.compare == null
        then "-"
        else "[compare](${c.compare})"
      } |\n")
      changes;

  # Markdown for one host. `limit` caps the package rows so four hosts stay well under
  # GitHub's 65536-character PR body limit; the totals line always carries the full count.
  renderHost = host: limit: d: let
    arrow = a: b:
      if a == b
      then "`${a}` (unchanged)"
      else "`${a}` -> `${b}`";
    rows =
      (map (c: "| `${c.name}` | `${c.from}` | `${c.to}` |") d.changed)
      ++ (map (a: "| `${a.name}` | (new) | `${a.version}` |") d.added)
      ++ (map (r: "| `${r.name}` | `${r.version}` | (removed) |") d.removed);
    shown = builtins.genList (i: builtins.elemAt rows i) (
      if builtins.length rows > limit
      then limit
      else builtins.length rows
    );
    elided = builtins.length rows - builtins.length shown;
    counts = "${toString (builtins.length d.changed)} changed, ${toString (builtins.length d.added)} added, ${toString (builtins.length d.removed)} removed";
  in
    "### ${host}\n\n"
    + "- NixOS: ${arrow d.nixos.from d.nixos.to}\n"
    + "- Kernel: ${arrow d.kernel.from d.kernel.to}\n"
    + "- systemPackages: ${counts}\n\n"
    + (
      if rows == []
      then ""
      else
        "<details><summary>Package versions (${counts})</summary>\n\n"
        + "| Package | Before | After |\n|---|---|---|\n"
        + concatMap (r: r + "\n") shown
        + (
          if elided > 0
          then "\n${toString elided} more rows elided; run `bin/update/pkg-diff host <old> <new> ${host}` for all.\n"
          else ""
        )
        + "\n</details>\n"
    );
}
