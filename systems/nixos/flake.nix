{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    stylix = {
      url = "github:danth/stylix";
    };
  };
  outputs = inputs @ {...}: {
    nixosConfigurations =
      {}
      // (import ../../hosts/langhus.nix {inherit inputs;})
      // (import ../../hosts/drakkar.nix {inherit inputs;})
      // (import ../../hosts/huginn.nix {inherit inputs;});
  };
}
