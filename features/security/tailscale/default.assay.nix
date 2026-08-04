# Colocated suite: tailscale wiring (disabled by default) + TPM off.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
      settings = { hostname = "testhost"; username = "alice"; };
    };

in
  assay.suite "tailscale" {
    disabled = assay.eq mod.services.tailscale.enable false;
    tpmOff = assay.eq mod.systemd.services.tailscaled.environment.TS_USE_TPM "false";
    trustedIface = assay.eq mod.networking.firewall.trustedInterfaces [ "tailscale0" ];
  }
