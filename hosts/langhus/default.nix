{
  inputs,
  specialArgs,
  ...
}: let
  settings = {
    hostname = "langhus";
    stateVersion = "24.05";
    system = "x86_64-linux";
    hostPlatform = {
      system = "x86_64-linux";
    };
    userdir = "/home/tom";
    useremail = "tom.wieland@gmail.com";
    userfullname = "Tom Wieland";
    username = "tom";
  };
in
  inputs.nixpkgs.lib.nixosSystem {
    specialArgs =
      specialArgs
      // {
        inherit settings;
      };
    modules = [
      ./system
    ];
  }
