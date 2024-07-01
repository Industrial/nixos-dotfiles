{
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Flake Parts
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Nix Darwin
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # MicroVM
    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    # NixVim
    nixvim.url = "https://flakehub.com/f/nix-community/nixvim/0.1.*.tar.gz";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    # Nix VSCode Extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";

    # Stylix
    stylix.url = "https://flakehub.com/f/danth/stylix/0.1.*.tar.gz";
    stylix.inputs.nixpkgs.follows = "nixpkgs";

    # Cryptpad
    cryptpad.url = "https://flakehub.com/f/michaelshmitty/cryptpad/2.2.0.tar.gz";
    cryptpad.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs @ {...}:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      flake = {
        nixosConfigurations = {} // (import ./hosts/langhus.nix {inherit inputs;});
        darwinConfigurations = {} // (import ./hosts/smithja.nix {inherit inputs;});
      };
    };
}
