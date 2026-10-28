# Colocated suite: V-268092 — audit=1 on the kernel command line via V-268080.
let
  assay = import ./../../../../common/assay/default.nix;

  self = import ./V-268092.nix {};

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

  params = evaluated.boot.kernelParams;
in
  assay.suite "stig-V-268092" {
    emitsNothing = assay.eq self {};

    auditEnabledOnCmdline = assay.eq (builtins.elem "audit=1" params) true;
    # Exactly once. Declaring it in this control as well is what would break that.
    appearsExactlyOnce = assay.eq (builtins.length (builtins.filter (p: p == "audit=1") params)) 1;
  }
