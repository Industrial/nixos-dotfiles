# Colocated suite: V-268093 — audit backlog limit raised to 8192.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268093.nix {};

  evaluated =
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      system = "x86_64-linux";
      modules = [
        ./V-268080.nix
        ./V-268093.nix
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
  assay.suite "stig-V-268093" {
    backlogLimit = assay.eq mod.security.audit.backlogLimit 8192;

    # Higher than the nixpkgs default of 1024 — this control genuinely changes something.
    exceedsNixpkgsDefault = assay.eq (mod.security.audit.backlogLimit > 1024) true;

    # The option drives the kernel parameter, so setting both would duplicate it.
    kernelParamDerived = assay.eq (builtins.elem "audit_backlog_limit=8192" params) true;
    kernelParamAppearsOnce = assay.eq (builtins.length (builtins.filter (p: builtins.match "audit_backlog_limit=.*" p != null) params)) 1;
  }
