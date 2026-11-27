# Option census for #417 S1: which NixOS options each fleet host defines.
#
# Normally driven by run-census.sh (also times the plain toplevel eval) and folded into
# s1-options.json by summarise.sh. By hand, one host at a time from the repo root (never `path:`):
#   nix eval --impure --json --expr \
#     'import ./docs/research/417/census.nix { flakeRef = "git+file://'$PWD'"; host = "drakkar"; }' \
#     > .tmp/census-drakkar.json   # summarise.sh also wants run-census.sh time-*.txt
# then `docs/research/417/summarise.sh .tmp > docs/research/417/s1-options.json`.
#
# "Defined" means the option's winning priority is below mkOptionDefault (1500): some module set
# it, beyond the declared default. Each definition's file is classified as `repo:<rel>`,
# `nixpkgs:<rel>`, `<input>:<rel>` or `other:<file>`. Only file names are read, never values, so
# the census costs about what a normal `config` eval costs.
{
  flakeRef,
  host,
}: let
  flake = builtins.getFlake flakeRef;
  nixos = flake.nixosConfigurations.${host};
  inherit (flake.inputs.nixpkgs) lib;

  # Store prefixes of the root flake and every direct input, longest first so a nested
  # path wins over its parent.
  prefixes =
    lib.sort (a: b: lib.stringLength a.p > lib.stringLength b.p)
    ([
        {
          n = "repo";
          p = "${flake.outPath}/";
        }
      ]
      ++ lib.mapAttrsToList (n: i: {
        inherit n;
        p = "${i.outPath}/";
      }) (lib.filterAttrs (_: i: i ? outPath) flake.inputs));

  classify = file: let
    f =
      if file == null
      then "<null>"
      else toString file;
    hit = lib.findFirst (x: lib.hasPrefix x.p f) null prefixes;
  in
    if hit == null
    then "other:${f}"
    else "${hit.n}:${lib.removePrefix hit.p f}";

  # Walk `options`, stopping at options; tolerate subtrees that throw.
  walk = path: v: let
    t = builtins.tryEval (lib.isOption v);
  in
    if !t.success
    then []
    else if t.value
    then [
      {
        inherit path;
        opt = v;
      }
    ]
    else if builtins.isAttrs v
    then
      lib.concatLists (lib.mapAttrsToList (
          n: c:
            if n == "_module" || n == "_type"
            then []
            else walk (path ++ [n]) c
        )
        v)
    else [];

  all = walk [] nixos.options;

  describe = {
    path,
    opt,
  }: let
    r = builtins.tryEval (
      let
        prio = opt.highestPrio or 1500;
        # Check the priority first: isDefined on an unset option forces its default, and some
        # upstream defaults (lanzaboote keyFile) do not evaluate when their inputs are unset.
        defd = prio < 1500 && opt.isDefined;
        defs =
          if defd
          then lib.unique (map (d: classify d.file) opt.definitionsWithLocations)
          else [];
      in
        builtins.deepSeq defs {
          inherit defd defs prio;
        }
    );
  in
    if !r.success
    then {
      p = lib.concatStringsSep "." path;
      err = true;
    }
    else if !r.value.defd
    then null
    else {
      p = lib.concatStringsSep "." path;
      d = r.value.defs;
      decl = map classify (opt.declarations or []);
      pr = r.value.prio;
    };

  described = map describe all;
  defined = lib.filter (x: x != null && !(x.err or false)) described;
  errors = map (x: x.p) (lib.filter (x: x != null && (x.err or false)) described);

  cfg = nixos.config;
  names = a: builtins.length (builtins.attrNames a);

  # Per-entry ownership of the attrsOf subtrees S3 would own first: entry name -> the source
  # classes ("repo", "nixpkgs", an input name) whose definitions name it. Entries named only
  # under a false mkIf are dropped by intersecting with the final config.
  srcOf = file: builtins.head (lib.splitString ":" (classify file));
  owners = path: let
    opt = lib.getAttrFromPath path nixos.options;
    final = builtins.attrNames (lib.getAttrFromPath path cfg);
    perDef =
      lib.concatMap (
        d:
          if builtins.isAttrs d.value
          then
            map (n: {
              inherit n;
              s = srcOf d.file;
            }) (builtins.attrNames d.value)
          else []
      )
      opt.definitionsWithLocations;
    grouped = builtins.groupBy (x: x.n) perDef;
  in
    lib.genAttrs final (n: lib.unique (map (x: x.s) (grouped.${n} or [])));
  # List-valued subtrees: element count per source class.
  listOwners = path: let
    opt = lib.getAttrFromPath path nixos.options;
  in
    lib.foldl' (acc: d: let
      s = srcOf d.file;
      k =
        if builtins.isList d.value
        then builtins.length d.value
        else 0;
    in
      acc // {${s} = (acc.${s} or 0) + k;}) {}
    opt.definitionsWithLocations;
in {
  inherit host errors;
  nixpkgsRev = flake.inputs.nixpkgs.rev or "unknown";
  repoRev = flake.rev or flake.dirtyRev or "unknown";
  totalOptions = builtins.length all;
  options = defined;
  ownership = {
    "systemd.services" = owners ["systemd" "services"];
    "systemd.sockets" = owners ["systemd" "sockets"];
    "systemd.timers" = owners ["systemd" "timers"];
    "systemd.user.services" = owners ["systemd" "user" "services"];
    "users.users" = owners ["users" "users"];
    "users.groups" = owners ["users" "groups"];
    "environment.etc" = owners ["environment" "etc"];
    "system.activationScripts" = owners ["system" "activationScripts"];
    "systemd.tmpfiles.rules" = listOwners ["systemd" "tmpfiles" "rules"];
    "environment.systemPackages" = listOwners ["environment" "systemPackages"];
  };
  # Sizes of the subtrees S3 would own first.
  subtrees = {
    systemdServices = names cfg.systemd.services;
    systemdSockets = names cfg.systemd.sockets;
    systemdTimers = names cfg.systemd.timers;
    systemdPaths = names cfg.systemd.paths;
    systemdMounts = builtins.length cfg.systemd.mounts;
    systemdTmpfilesRules = builtins.length cfg.systemd.tmpfiles.rules;
    systemdUnitsTotal = names cfg.systemd.units;
    systemdUserServices = names cfg.systemd.user.services;
    users = names cfg.users.users;
    normalUsers = names (lib.filterAttrs (_: u: u.isNormalUser) cfg.users.users);
    groups = names cfg.users.groups;
    etcEntries = names (lib.filterAttrs (_: e: e.enable) cfg.environment.etc);
    systemPackages = builtins.length cfg.environment.systemPackages;
    activationScripts = names cfg.system.activationScripts;
    fileSystems = names cfg.fileSystems;
    firewallTCP = builtins.length cfg.networking.firewall.allowedTCPPorts;
  };
}
