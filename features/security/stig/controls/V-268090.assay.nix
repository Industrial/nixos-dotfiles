# Colocated suite: V-268090 — audit package installed as a consequence of V-268080.
#
# Proves the claim against the real nixpkgs module: evaluating a minimal system with only
# V-268080's settings must put the audit package in systemPackages. If nixpkgs ever stops
# doing that, this fails and V-268090 needs a real implementation.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268090.nix {};

  evaluated =
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      system = "x86_64-linux";
      modules = [
        ./V-268080.nix
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/null";
            fsType = "ext4";
          };
          system.stateVersion = "25.05";
        }
      ];
    })
    .config;

  packageNames = map (p: p.pname or p.name or "") evaluated.environment.systemPackages;
in
  assay.suite "stig-V-268090" {
    emitsNothing = assay.eq self {};

    # V-268080 enables security.audit; nixpkgs then installs cfg.package for us.
    auditPackageIsInstalled = assay.eq (builtins.elem "audit" packageNames) true;
  }
