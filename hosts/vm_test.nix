{inputs, ...}: let
  name = "vm_test";
  system = "x86_64-linux";
  username = "tom";
  version = "24.11";
  settings = {
    inherit system username;
    hostname = "${name}";
    stateVersion = "${version}";
    hostPlatform = {
      inherit system;
    };
    userdir = "/home/${username}";
    useremail = "${username}@${system}.local";
    userfullname = "${username}";
  };
in {
  "${settings.hostname}" = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs settings;
    };
    modules = [
      inputs.microvm.nixosModules.microvm
      {
        networking = {
          hostName = name;
        };
        microvm = {
          hypervisor = "qemu";
        };
      }
    ];
  };
}
