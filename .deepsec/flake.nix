{
  description = "deepsec workspace: NixOS-friendly shell (Claude Code from nixpkgs)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {nixpkgs, ...}: let
    mkShell = system: let
      # claude-code is unfree in nixpkgs; allow it for this dev shell only.
      pkgs = import nixpkgs.outPath {
        inherit system;
        config.allowUnfree = true;
      };
    in
      pkgs.mkShell {
        packages = with pkgs; [
          nodejs_22
          pnpm
          claude-code
        ];
        shellHook = ''
          export CLAUDE_CODE_EXECUTABLE="${pkgs.claude-code}/bin/claude"
        '';
      };
  in {
    devShells = {
      x86_64-linux.default = mkShell "x86_64-linux";
      aarch64-linux.default = mkShell "aarch64-linux";
    };
  };
}
