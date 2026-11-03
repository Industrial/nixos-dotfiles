# Colocated suite: V-268093 — audit backlog limit raised above the STIG floor.
#
# The STIG states a minimum ("of sufficient size"), so these claims assert a floor rather than
# an exact value. Pinning the exact number would make this suite fail every time the fleet
# raises headroom, which is the opposite of what the control protects.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268093.nix {};

  stigFloor = 8192;
  configured = mod.security.audit.backlogLimit;

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
    # The requirement itself: at least the 8192 named in the fix text.
    meetsStigFloor = assay.eq (configured >= stigFloor) true;

    # Higher than the nixpkgs default of 1024 — this control genuinely changes something.
    exceedsNixpkgsDefault = assay.eq (configured > 1024) true;

    # Headroom above the floor is deliberate, not an accident: V-268095 audits every unlink,
    # so bulk deletions overrun an 8192-entry backlog and stall userspace via backlog_wait_time.
    hasBurstHeadroom = assay.eq (configured >= 65536) true;

    # The option drives the kernel parameter, so setting both would duplicate it. Derived from
    # the configured value rather than hardcoded, so the two can never drift apart.
    kernelParamDerived = assay.eq (builtins.elem "audit_backlog_limit=${toString configured}" params) true;
    kernelParamAppearsOnce = assay.eq (builtins.length (builtins.filter (p: builtins.match "audit_backlog_limit=.*" p != null) params)) 1;
  }
