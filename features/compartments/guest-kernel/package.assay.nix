# Colocated suite for features/compartments/guest-kernel/package.nix (#425).
# Asserts on the evaluated derivation without building it: the source, the outputs it
# promises, and the Kconfig check that makes config.nix the kernel's whole surface.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  inherit (nixos.evalSystem {modules = [];}) pkgs;
  drv = pkgs.callPackage ./package.nix {};
  inet = pkgs.callPackage ./package.nix {withInet = true;};
  contains = needle: s: lib.hasInfix needle (builtins.unsafeDiscardStringContext s);
in
  assay.suite "guest-kernel-package" {
    name = assay.eq [drv.pname inet.pname] ["compartment-guest-kernel" "compartment-guest-kernel-inet"];
    tracksTheLts = assay.eq drv.version pkgs.linux_6_18.version;
    x86_64Only = assay.eq drv.meta.platforms ["x86_64-linux"];
    buildsBothImages = assay.eq drv.buildFlags ["vmlinux" "bzImage"];
    startsFromAllnoconfig = assay.eq (contains "allnoconfig" drv.configurePhase) true;
    # A requested value Kconfig drops or changes fails the build.
    rejectsSilentKconfigChanges = assay.eq (contains "Kconfig rejected part of config.nix" drv.configurePhase) true;
    installsVmlinuxBzimageConfigSizes =
      assay.eq (map (f: contains "$out/${f}" drv.installPhase) ["vmlinux" "bzImage" "config" "sizes.txt"]) [true true true true];
    fragmentIsConfigNix = assay.eq drv.fragment (import ./config.nix {inherit lib;}).fragment;
  }
