# Colocated suite: tor client daemon, no browser.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {};
in
  assay.suite "tor" {
    serviceEnabled = assay.eq mod.services.tor.enable true;

    # The daemon alone does not provide a SOCKS proxy for applications; client.enable is what
    # makes it usable, and is easy to omit.
    clientEnabled = assay.eq mod.services.tor.client.enable true;

    # Tor Browser was removed on purpose, along with its local profile and cache. This feature
    # must stay daemon-only, so a reintroduced systemPackages entry fails here.
    installsNoPackages = assay.eq (mod ? environment) false;
  }
