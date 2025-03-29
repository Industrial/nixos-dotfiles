{...}: {
  # Enable networkd for network configuration
  networking = {
    useNetworkd = true;
  };

  networking = {
    # NAT configuration for internet access
    nat = {
      enable = true;
      # Using the actual network interface from the host
      externalInterface = "eno1";
    };

    # # Firewall rules to control VM-to-VM communication
    # firewall = {
    #   enable = true;
    # };
  };

  # This is the host configuration for microvm. Include
  # `inputs.microvm.nixosModules.host` and this configuration.
  microvm = {
    autostart = [
      "vm_test"
      "vm_web"
      # "vm_database"
      # "vm_management"
    ];
  };
}
