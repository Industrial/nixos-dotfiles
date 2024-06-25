{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    ansifilter.url = "path:/Users/twieland/.dotfiles/features/cli/ansifilter";
    ansifilter.inputs.nixpkgs.follows = "nixpkgs";
    aria2.url = "path:/Users/twieland/.dotfiles/features/cli/aria2";
    # aria2.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ ... }: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = inputs.nixpkgs.lib.systems.flakeExposed;
    flake = {
      darwinConfigurations = {} // (import ./hosts/smithja.nix {inherit inputs;});
    };

    # perSystem = { self', inputs', pkgs, system, config, ... }: {
    #   # # TODO: Replace with flake-parts system.
    #   # # TODO: Put in file.
    #   # # packages.aarch64-darwin.vm = self.nixosConfigurations.vm.config.system.build.vm;
    #   # treefmt.config = {
    #   #   projectRootFile = "flake.nix";
    #   #   programs.nixpkgs-fmt.enable = true;
    #   # };
    #   packages.default = self'.packages.activate;
    #   # I don't want a default dev shell per system. I want them to be different
    #   # per system because each system uses different features.
    #   # devShells.default = pkgs.mkShell {
    #   #   inputsFrom = [
    #   #     # inputs'.ansifilter.packages.${system}.default
    #   #     # config.treefmt.build.devShell
    #   #   ];
    #   #   packages = with pkgs; [
    #   #     # just
    #   #     # colmena
    #   #     nixd
    #   #     # inputs'.ragenix.packages.default
    #   #     inputs.ansifilter.packages.${system}.default
    #   #     inputs.aria2.packages.${system}.default
    #   #   ];
    #   # };
    #   # systemConfigs.default = {
    #   # } // inputs.ansifilter.systemConfigs.${system}.default;
    # };
  };
}

