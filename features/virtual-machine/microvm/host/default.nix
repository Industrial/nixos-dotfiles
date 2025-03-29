{...}: {
  # This is the host configuration for microvm. Include
  # `inputs.microvm.nixosModules.host` and this configuration.
  microvm = {
    autostart = [
      "vm_test"
    ];
  };
}
