{
  inputs,
  specialArgs,
  ...
}: let
  settings = {
    hostname = "smithja";
    stateVersion = 4;
    system = "aarch64-darwin";
    hostPlatform = {
      config = "aarch64-apple-darwin";
      system = "aarch64-darwin";
    };
    userdir = "/Users/twieland";
    useremail = "twieland@suitsupply.com";
    userfullname = "Tom Wieland";
    username = "twieland";
  };
in
  inputs.nix-darwin.lib.darwinSystem {
    specialArgs =
      specialArgs
      // {
        inherit settings;
      };
    modules = [
      ./system
    ];
  }
