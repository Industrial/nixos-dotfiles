# Colocated suite: V-268152 — only root and wheel may use the nix daemon.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268152.nix {};
in
  assay.suite "stig-V-268152" {
    allowedUsers = assay.eq mod.nix.settings.allowed-users ["root" "@wheel"];

    # The wildcard must be gone — that is the entire control.
    doesNotAllowEveryone = assay.eq (builtins.elem "*" mod.nix.settings.allowed-users) false;
    # @wheel is a group reference, not a user; losing the @ would silently match nothing.
    wheelIsAGroupReference = assay.eq (builtins.elem "@wheel" mod.nix.settings.allowed-users) true;

    # nixpkgs defaults to [ "*" ], so this narrows rather than restates.
    nixpkgsDefaultIsWildcard = assay.eq (fixture.evalWith []).nix.settings.allowed-users ["*"];
  }
