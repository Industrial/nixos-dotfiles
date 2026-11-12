# Colocated suite: emerald compiler + language server from the flake input.
let
  assay = import ./../../../common/assay/default.nix;
  # The real package is a derivation; stub overrideAttrs so the suite can see
  # both which package was selected and which attrs the override sets.
  stubPackage = {
    name = "emerald-pkg";
    overrideAttrs = f: {
      name = "emerald-pkg";
      overridden = f {};
    };
  };
  mod = import ./default.nix {
    inputs.emerald.packages."x86_64-linux".emerald = stubPackage;
    pkgs.stdenv.hostPlatform.system = "x86_64-linux";
  };
in
  assay.suite "emerald" {
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;

    # Selected per host platform from the flake input, not hardcoded to one system.
    selectsPackageForHostPlatform =
      assay.eq (builtins.map (p: p.name) mod.environment.systemPackages) ["emerald-pkg"];

    # nixpkgs' cargoUseSystemLibs hook makes zstd-sys probe for a system
    # libzstd the flake's package does not carry, so the package must opt out.
    optsOutOfCargoUseSystemLibs =
      assay.eq
      (builtins.map (p: p.overridden.dontCargoUseSystemLibs) mod.environment.systemPackages)
      [true];
  }
