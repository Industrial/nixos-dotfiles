args @ {...}: let
  feature = import ./default.nix args;
in {
  test_microvm_socket = {
    expr = feature.microvm.socket;
    expected = "control.socket";
  };
  test_microvm_hypervisor = {
    expr = feature.microvm.hypervisor;
    expected = "qemu";
  };
  test_microvm_volumes = {
    expr = feature.microvm.volumes;
    expected = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 256;
      }
    ];
  };
  test_microvm_shares = {
    expr = feature.microvm.shares;
    expected = [
      {
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
  };
}
