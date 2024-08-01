{
  inputs,
  system,
  ...
}: {
  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    hooks = {
      # Nix
      alejandra.enable = true;
      deadnix.enable = true;
      flake-checker.enable = true;

      # Bash
      shellcheck.enable = true;
      beautysh.enable = true;

      # Markdown
      markdownlint.enable = true;

      # YAML
      check-yaml.enable = true;
      yamllint.enable = true;
      yamlfmt.enable = true;

      # TOML
      check-toml.enable = true;
      taplo.enable = true;

      # JSON
      check-json.enable = true;
      pretty-format-json.enable = true;

      # Git
      check-merge-conflicts.enable = true;
      commitizen = {
        enable = true;
        stages = ["commit-msg"];
      };

      # TypeScript / JavaScript
      eslint.enable = true;

      # Generic
      check-added-large-files.enable = true;
      check-case-conflicts.enable = true;
      check-executables-have-shebangs.enable = true;
      check-shebang-scripts-are-executable.enable = true;
      check-symlinks.enable = true;
      detect-aws-credentials.enable = true;
      detect-private-keys.enable = true;
      end-of-file-fixer.enable = true;
      fix-byte-order-marker.enable = true;
      forbid-new-submodules.enable = true;
      trim-trailing-whitespace.enable = true;

      unit-tests = {
        enable = true;
        name = "Unit tests";
        entry = "nix run nixpkgs#nix-unit -- --flake .#tests";
        pass_filenames = false;
        stages = ["pre-push"];
      };
    };
  };
}
