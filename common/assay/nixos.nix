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
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);

  # Source tree of a root flake input, fetched at its locked revision.
  fetchInput = name: let
    l = lock.nodes.${lock.nodes.root.inputs.${name}}.locked;
  in
    builtins.fetchTarball {
      url = "https://github.com/${l.owner}/${l.repo}/archive/${l.rev}.tar.gz";
      sha256 = l.narHash;
    };

  nixpkgs = fetchInput "nixpkgs";
  lib = import (nixpkgs + "/lib");

  defaultSettings = (import ../settings.nix {hostname = "assay-host";}).settings;

  # The least a NixOS system needs to evaluate: a root filesystem and a bootloader stance.
  base = {
    system.stateVersion = defaultSettings.stateVersion;
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };
    nixpkgs.config.allowUnfree = true;
  };

  # Flake-input stand-ins for modules that import from `inputs`. Only inputs a suite
  # actually reaches are forced, so an unused entry costs nothing.
  defaultInputs = {
    comin.nixosModules.comin = lib.modules.importApply ((fetchInput "comin") + "/nix/module.nix") {
      self.packages = {};
    };
  };
in rec {
  inherit lib fetchInput defaultSettings;

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
        inputs = defaultInputs // inputs;
      };
    };

  # Just the merged config, which is what nearly every claim reads.
  eval = args: (evalSystem args).config;

  # Names of everything in environment.systemPackages, for membership claims without
  # forcing derivation equality.
  packageNames = cfg: map lib.getName cfg.environment.systemPackages;
  hasPackage = cfg: name: builtins.elem name (packageNames cfg);

  # Every TCP/UDP port the firewall opens, across all interfaces and ranges' endpoints.
  # A feature that must stay tailnet-only should leave both of these empty.
  openTCPPorts = cfg:
    cfg.networking.firewall.allowedTCPPorts
    ++ lib.concatMap (i: i.allowedTCPPorts) (lib.attrValues cfg.networking.firewall.interfaces);
  openUDPPorts = cfg:
    cfg.networking.firewall.allowedUDPPorts
    ++ lib.concatMap (i: i.allowedUDPPorts) (lib.attrValues cfg.networking.firewall.interfaces);

  # The same module evaluated alone, minus `base`, is the baseline a claim can diff
  # against: "this feature adds no ports" is openTCPPorts (eval feature) == openTCPPorts baseline.
  baseline = eval {modules = [];};
}
