{...}: {
  # nixConfig = {
  #   extra-substituters = ["https://microvm.cachix.org"];
  #   extra-trusted-public-keys = ["microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="];
  # };
  microvm = {
    # socket = "control.socket";
    # hypervisor = "qemu";
    autostart = [
      "vm_test"
    ];
    # volumes = [
    #   {
    #     mountPoint = "/var";
    #     image = "var.img";
    #     size = 256;
    #   }
    # ];
    # shares = [
    #   {
    #     # use "virtiofs" for MicroVMs that are started by systemd
    #     proto = "9p";
    #     tag = "ro-store";
    #     # a host's /nix/store will be picked up so that no
    #     # squashfs/erofs will be built for it.
    #     source = "/nix/store";
    #     mountPoint = "/nix/.ro-store";
    #   }
    # ];
  };
}
