# Colocated suite: tor service and browser.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    config = {};
    lib = (import <nixpkgs> {}).lib;
    pkgs = {tor-browser = "tor-browser-pkg";};
  };
in
  assay.suite "tor" {
    serviceEnabled = assay.eq mod.services.tor.enable true;

    # The daemon alone does not provide a SOCKS proxy for applications; client.enable is what
    # makes it usable, and is easy to omit.
    clientEnabled = assay.eq mod.services.tor.client.enable true;

    installsBrowser = assay.eq mod.environment.systemPackages ["tor-browser-pkg"];
  }
