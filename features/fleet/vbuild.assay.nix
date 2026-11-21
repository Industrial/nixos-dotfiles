# Assay: vbuild as the Nix build hook — the hook command, and that it reads the same
# machines build-remote would (no host names of its own).
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ../../lib/features.nix {inherit lib;};

  alone = nixos.eval {modules = [./vbuild.nix];};
  withClient = nixos.eval {modules = [./vbuild.nix ./nix-remote-builder-client.nix];};
  hook = alone.nix.settings.build-hook;
  words = lib.splitString " " hook;

  catalog = features.enabledFeatures (features.evalSelection {modules = [{features.fleet.vbuild.enable = true;}];});
  offByDefault = features.enabledFeatures (features.evalSelection {modules = [];});
in
  assay.suite "vbuild" {
    # The hook is the vbuild binary, then its flags; Nix appends the verbosity.
    hookIsVbuild = assay.eq (lib.hasSuffix "/bin/vbuild" (builtins.head words)) true;

    # The children run this host's nix and ssh, not whatever is on the daemon's PATH.
    pinsNixAndSsh = assay.eq [
      (builtins.elem "${alone.nix.package}/bin/nix" words)
      (builtins.elem "${alone.programs.ssh.package}/bin/ssh" words)
    ] [true true];

    # Builders stay the remote-builder client's: vbuild adds no machines and no
    # `builders` setting of its own, so the list still comes from common/fleet.nix.
    noBuildersOfItsOwn = assay.eq (alone.nix.buildMachines == [] && !(alone.nix.settings ? builders && alone.nix.settings.builders != null && alone.nix.settings.builders != "")) true;
    sameMachinesAsTheClient =
      assay.eq (map (m: m.hostName) withClient.nix.buildMachines) (map (b: b.name) (import ../../common/fleet.nix).builders);

    # A feature switch like any other: in the catalog, off unless a host turns it on.
    inTheCatalog = assay.eq (builtins.elem "fleet.vbuild" catalog) true;
    offUnlessEnabled = assay.eq (builtins.elem "fleet.vbuild" offByDefault) false;
  }
