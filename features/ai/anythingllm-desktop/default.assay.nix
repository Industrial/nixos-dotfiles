# Colocated suite for features/ai/anythingllm-desktop/default.nix
#
# The feature installs the official AppImage, FHS-wrapped, and nothing else: a desktop
# app that runs on demand, with no service and no port of its own.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  cfg = nixos.eval {modules = [./default.nix];};
  app = lib.findFirst (p: lib.getName p == "anythingllm-desktop") null cfg.environment.systemPackages;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
in
  assay.suite "anythingllm-desktop" {
    installsDesktopApp = assay.eq (nixos.hasPackage cfg "anythingllm-desktop") true;
    addsOnlyTheApp = assay.eq added ["anythingllm-desktop"];
    pinsVersion = assay.eq (lib.getVersion app) "1.12.1";

    # The CDN has no per-version URL; x86_64 must fetch the x86_64 image.
    fetchesX86Image = assay.eq app.src.url "https://cdn.anythingllm.com/latest/AnythingLLMDesktop.AppImage";
    supportedPlatforms = assay.eq app.meta.platforms ["x86_64-linux" "aarch64-linux"];

    declaresNoSystemService = assay.eq (builtins.attrNames cfg.systemd.services) (builtins.attrNames nixos.baseline.systemd.services);
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
  }
