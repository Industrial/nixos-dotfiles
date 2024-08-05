{
  # For All Systems
  for-all-systems.url = "github:Industrial/for-all-systems";
  for-all-systems.inputs.nixpkgs.follows = "nixpkgs";

  # Nix Git Hooks
  git-hooks.url = "github:cachix/git-hooks.nix";
  git-hooks.inputs.nixpkgs.follows = "nixpkgs";

  # Nix GitHub Actions
  nix-github-actions.url = "github:nix-community/nix-github-actions";
  nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

  # Nix Unit
  nix-unit.url = "github:nix-community/nix-unit";
  nix-unit.inputs.nixpkgs.follows = "nixpkgs";

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
}
