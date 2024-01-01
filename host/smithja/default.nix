{
  inputs,
  config,
  withSystem,
  mkNixOS,
  ...
}: let
  settings = {
    hostname = "smithja";
    system = "aarch64-darwin";
    userdir = "/Users/twieland";
    useremail = "twieland@suitsupply.com";
    userfullname = "Tom Wieland";
    username = "twieland";
  };
  specialArgs = {
    inherit inputs;
    inherit settings;
    packages = inputs.packages.${settings.system};
  };
  pkgs = withSystem settings.system ({pkgs, ...}: pkgs);
in {
  flake.darwinConfigurations.${settings.hostname} = inputs.nixpkgs.lib.nixosSystem {
    inherit specialArgs;
    pkgs = pkgs;
    modules = [
      ./system
    ];
  };
  flake.homeConfigurations."${settings.username}@${settings.hostname}" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs;
    extraSpecialArgs = specialArgs;
    modules = [
      ./home-manager
    ];
  };
}
