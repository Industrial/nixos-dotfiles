# Minimal evaluated NixOS system, for suites that must check what a control actually produces
# rather than what its module literally declares.
#
# Several controls are satisfied by a *consequence* of another option — nixpkgs' audit module
# adds `audit=1` to the kernel command line, the etc activation makes /etc/audit a tree of
# root-owned store symlinks — and the only honest way to assert that is to evaluate a system
# and look. This is that system: small enough to evaluate quickly, real enough that the
# nixpkgs modules under test behave normally.
#
# Usage:
#   fixture = import ./../lib/fixture.nix;
#   config  = fixture.evalWith [ ./V-268080.nix ./V-268110.nix ];
#
# Not a substitute for wave 2's VM tests: this proves what the configuration evaluates to, not
# what a booted machine does. Controls whose requirement is only observable at runtime (file
# modes under /var/log/journal, sticky bits) stay verify-only until the VM test exists.
let
  stubHost = {
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "/dev/null";
      fsType = "ext4";
    };
    system.stateVersion = "25.05";
  };
in rec {
  inherit stubHost;

  evalWith = modules:
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      system = "x86_64-linux";
      modules = modules ++ [stubHost];
    })
    .config;

  # The etc entries a control cares about, as { name = { mode; user; group; }; }.
  etcMatching = config: pattern:
    builtins.listToAttrs (map (n: {
        name = n;
        value = {
          inherit (config.environment.etc.${n}) mode user group;
        };
      }) (builtins.filter (n: builtins.match pattern n != null)
        (builtins.attrNames config.environment.etc)));

  # Split a systemd-tmpfiles line into its fields: type path mode user group age.
  tmpfilesFields = rule: builtins.filter (f: builtins.isString f && f != "") (builtins.split " +" rule);
}
