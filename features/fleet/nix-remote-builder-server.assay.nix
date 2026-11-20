# Assay: fleet remote builder server — advertises the features clients route by.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./nix-remote-builder-server.nix];};
  features = cfg.nix.settings.system-features;
in
  assay.suite "nix-remote-builder-server" {
    # nix-remote-builder-client routes big-parallel and kvm jobs here; a builder that
    # does not advertise them is never picked.
    advertisesKvm = assay.eq (builtins.elem "kvm" features) true;
    advertisesBigParallel = assay.eq (builtins.elem "big-parallel" features) true;
    advertisesNixosTest = assay.eq (builtins.elem "nixos-test" features) true;
  }
