{
  inputs,
  config,
  withSystem,
  mkNixOS,
  ...
}: let
  settings = {
    hostname = "langhus";
    stateVersion = "24.05";
    system = "x86_64-linux";
    userdir = "/home/tom";
    useremail = "tom.wieland@gmail.com";
    userfullname = "Tom Wieland";
    username = "tom";
  };
  specialArgs = {
    inherit inputs;
    inherit settings;
    packages = inputs.packages.${settings.system};
  };
  pkgs = withSystem settings.system ({pkgs, ...}: pkgs);
in {
  flake.nixosConfigurations.${settings.hostname} = inputs.nixpkgs.lib.nixosSystem {
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
