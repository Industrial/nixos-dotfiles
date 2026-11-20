# Evaluate feature modules against the real NixOS option tree.
#
# Suites that regex-match a module's source pass whenever the text looks right, so a
# refactor (mkMerge, a helper, an import that sets the option elsewhere) can break the
# behaviour without failing the test, and a comment can fail it without any behaviour
# change. This helper evaluates the module the way a host does and hands back `config`,
# so claims are about what the system ends up with.
#
# nixpkgs (and any other input) is pinned from the root flake.lock rather than taken from
# <nixpkgs>, so suites evaluate against the same tree the fleet builds — and an option a
# module sets that does not exist in that tree is an eval error, not a silent pass.
#
#   nixos = import ../../common/assay/nixos.nix;
#   cfg = nixos.eval {modules = [./foo.nix];};
#   assay.eq cfg.services.foo.enable true
let
  repo = ../..;
  lock = builtins.fromJSON (builtins.readFile (repo + "/flake.lock"));

  # The root flake's inputs, resolved from flake.lock exactly as `nix` would — the same
  # algorithm as Nix's own call-flake.nix, follows included — but without evaluating the
  # root flake itself, which would copy the whole repository into the store. Every
  # input is lazy: a suite pays only for the inputs its modules actually reach.
  resolve = spec:
    if builtins.isList spec
    then byPath lock.root spec
    else spec;
  byPath = node: path:
    if path == []
    then node
    else byPath (resolve lock.nodes.${node}.inputs.${builtins.head path}) (builtins.tail path);

  nodes = builtins.mapAttrs (key: node: let
    locked = node.locked;
    # Relative path inputs (rust/tools/*) are relative to the repository root.
    sourceInfo =
      if locked.type == "path" && !(lib.hasPrefix "/" locked.path)
      then {outPath = repo + "/${locked.path}";}
      else builtins.fetchTree (builtins.removeAttrs locked ["dir"]);
    outPath = sourceInfo.outPath + (lib.optionalString (locked ? dir) "/${locked.dir}");
    inputs = builtins.mapAttrs (_: spec: nodes.${resolve spec}) (node.inputs or {});
    outputs = (import (outPath + "/flake.nix")).outputs (inputs // {self = result;});
    result =
      outputs
      // sourceInfo
      // {
        inherit outPath inputs outputs sourceInfo;
        _type = "flake";
      };
  in
    if node.flake or true
    then result
    else sourceInfo // {inherit outPath;})
  (builtins.removeAttrs lock.nodes [lock.root]);

  # What `inputs` is inside a host's modules (lib/mk-host.nix passes the root inputs).
  flakeInputs = builtins.mapAttrs (_: spec: nodes.${resolve spec}) lock.nodes.${lock.root}.inputs;

  # lib must not come from the resolver, which itself needs lib (hasPrefix, optionalString).
  nixpkgsLocked = lock.nodes.${resolve lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
  nixpkgs = builtins.fetchTree nixpkgsLocked;
  lib = import (nixpkgs + "/lib");

  defaultSettings = (import ../settings.nix {hostname = "assay-host";}).settings;

  # The least a NixOS system needs to evaluate: a root filesystem and a bootloader stance.
  base = {
    system.stateVersion = lib.mkDefault defaultSettings.stateVersion;
    boot.loader.grub.enable = false;
    # mkDefault: a module under test that declares its own root (disko, a host's
    # filesystems.nix) must win, not conflict on fsType.
    fileSystems."/" = lib.mkDefault {
      device = "none";
      fsType = "tmpfs";
    };
    nixpkgs.config.allowUnfree = true;
  };
in rec {
  inherit lib defaultSettings flakeInputs;

  # Full evaluation result (config, options, …) for `modules` on top of `base`.
  evalSystem = {
    modules,
    settings ? {},
    inputs ? {},
  }:
    import (nixpkgs + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      modules = [base] ++ modules;
      specialArgs = {
        settings = defaultSettings // settings;
        inputs = flakeInputs // inputs;
      };
    };

  # Just the merged config, which is what nearly every claim reads.
  eval = args: (evalSystem args).config;

  # Names of everything in environment.systemPackages, for membership claims without
  # forcing derivation equality.
  packageNames = cfg: map lib.getName cfg.environment.systemPackages;
  hasPackage = cfg: name: builtins.elem name (packageNames cfg);

  # Every TCP/UDP port the firewall opens on ANY interface: the global lists plus every
  # per-interface rule, tailscale0's included. The strict bar for a feature that must add
  # no ports at all. (Ranges are separate: networking.firewall.allowed*PortRanges.)
  openTCPPorts = cfg:
    cfg.networking.firewall.allowedTCPPorts
    ++ lib.concatMap (i: i.allowedTCPPorts) (lib.attrValues cfg.networking.firewall.interfaces);
  openUDPPorts = cfg:
    cfg.networking.firewall.allowedUDPPorts
    ++ lib.concatMap (i: i.allowedUDPPorts) (lib.attrValues cfg.networking.firewall.interfaces);

  # Ports reachable from an UNTRUSTED interface: the global lists, plus per-interface rules
  # on interfaces outside trustedInterfaces. A port opened only on tailscale0 is not
  # public — tailscale0 is trusted, so it is reachable from the tailnet and nowhere else.
  publicTCPPorts = cfg: publicPorts "allowedTCPPorts" cfg;
  publicUDPPorts = cfg: publicPorts "allowedUDPPorts" cfg;
  publicPorts = attr: cfg: let
    fw = cfg.networking.firewall;
    untrusted = lib.filterAttrs (n: _: !(builtins.elem n fw.trustedInterfaces)) fw.interfaces;
  in
    lib.unique (lib.sort lib.lessThan (fw.${attr} ++ lib.concatMap (i: i.${attr}) (lib.attrValues untrusted)));

  # The same module evaluated alone, minus `base`, is the baseline a claim can diff
  # against: "this feature adds no ports" is openTCPPorts (eval feature) == openTCPPorts baseline.
  baseline = eval {modules = [];};
}
