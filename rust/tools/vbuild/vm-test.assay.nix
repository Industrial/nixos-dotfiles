# Colocated suite for rust/tools/vbuild/vm-test.nix — the shape of the two-node test,
# evaluated, not built (building it boots two VMs; see the file's header).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./vm-test.nix {inherit pkgs;};
  client = test.nodes.client;
  builder = test.nodes.builder;
  machine = builtins.head client.nix.buildMachines;
in
  assay.suite "vbuild-vm-test" {
    twoNodes = assay.eq (builtins.attrNames test.nodes) ["builder" "client"];

    # The client runs the feature under test, not a copy of its settings.
    clientHookIsVbuild = assay.eq (lib.hasInfix "/bin/vbuild " client.nix.settings.build-hook) true;

    # The builder-only feature is what forces the remote build: the builder has it,
    # the machines entry advertises it, the client lacks it.
    featureOnlyOnTheBuilder = assay.eq [
      (builtins.elem "vbuild-remote" builder.nix.settings.system-features)
      (builtins.elem "vbuild-remote" machine.supportedFeatures)
      (builtins.elem "vbuild-remote" (client.nix.settings.system-features or []))
    ] [true true false];

    # Builders come from nix.buildMachines (/etc/nix/machines), as on the fleet.
    machinesFileDriven = assay.eq [client.nix.distributedBuilds machine.hostName] [true "builder"];

    # No substituters: every path either machine needs is copied or built here.
    offline = assay.eq [client.nix.settings.substituters builder.nix.settings.substituters] [[] []];
  }
