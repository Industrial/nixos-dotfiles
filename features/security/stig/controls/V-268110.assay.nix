# Colocated suite: V-268110 — auditd writes logs group-owned by root.
#
# Asserts both the declaration and that it actually reaches a generated auditd.conf, since the
# whole point of deviating from the published fix text was to go through the option that owns
# that file.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268110.nix {};

  evaluated =
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      system = "x86_64-linux";
      modules = [
        ./V-268080.nix
        ./V-268110.nix
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
in
  assay.suite "stig-V-268110" {
    logGroupIsRoot = assay.eq mod.security.auditd.settings.log_group "root";

    # Declared through the auditd module's settings, so it lands in the file that module owns
    # rather than colliding with it via environment.etc.
    reachesEvaluatedConfig = assay.eq evaluated.security.auditd.settings.log_group "root";
  }
