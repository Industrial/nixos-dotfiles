{settings, ...}: {
  services = {
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };

  # Disable TPM usage to prevent lockout issues
  # TPM lockout can occur when there are too many failed authentication attempts,
  # causing Tailscale to fail to unseal its encrypted state file.
  # Disabling TPM still provides encryption, just not hardware-backed.
  systemd.services.tailscaled = {
    environment = {
      TS_USE_TPM = "false";
    };
  };

  networking = {
    firewall = {
      trustedInterfaces = ["tailscale0"];
    };
  };
}
