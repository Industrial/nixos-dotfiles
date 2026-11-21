# Colocated suite for features/cli/vfetch — the vfetch CLI, built from rust/tools/vfetch,
# with the host's nix on its PATH for the import step.
#
# Evaluated against the real NixOS option tree. vdeploy (#159) calls the installed
# binary, so the claims pin that it is installed, that it is the wrapper (the import
# runs `nix copy`, and a systemd unit's PATH may have no nix), and that the wrapper
# adds this host's nix after the caller's PATH rather than in front of it.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  cfg = nixos.eval {
    modules = [./default.nix];
    settings.hostname = "probe";
  };
  pkg = lib.findFirst (p: lib.getName p == "vfetch") null cfg.environment.systemPackages;
  # Text comparison only: hasInfix's pattern may not carry store-path context.
  plain = builtins.unsafeDiscardStringContext;
in
  assay.suite "features-cli-vfetch" {
    installsVfetch = assay.eq (nixos.hasPackage cfg "vfetch") true;
    mainProgram = assay.eq pkg.meta.mainProgram "vfetch";
    wrapsTheBinary = assay.eq (lib.hasInfix "wrapProgram $out/bin/vfetch" pkg.buildCommand) true;
    hostNixAfterCallersPath =
      assay.eq (lib.hasInfix (plain "--suffix PATH : ${cfg.nix.package}/bin") (plain pkg.buildCommand)) true;
  }
