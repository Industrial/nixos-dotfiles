systems: {inputs, ...}:
inputs.nix-github-actions.lib.mkGithubMatrix {
  checks =
    inputs.for-all-systems.forAllSystems {
      nixpkgs = inputs.nixpkgs;
      systems = ["x86_64-linux" "aarch64-darwin"];
    } ({
      system,
      pkgs,
    }:
      import ./checks.nix {inherit inputs system pkgs;});
}
