{
  inputs,
  pkgs,
  ...
}: let
  # Dotfiles Rust coreutils for devenv. `languages.rust` pulls in a stdenv whose PATH lists
  # pkgs.coreutils before `packages`, so we also prepend these in `enterShell` (see below).
  inherit (pkgs.lib) hiPrio;
  dotfilesCoreutils = [
    (hiPrio (pkgs.callPackage ./rust/tools/wc {}))
    (hiPrio (pkgs.callPackage ./rust/tools/cat {}))
    (hiPrio (pkgs.callPackage ./rust/tools/sort {}))
    (hiPrio (pkgs.callPackage ./rust/tools/ls {}))
    (hiPrio (pkgs.callPackage ./rust/tools/head {}))
  ];
  dotfilesCoreutilsBin = pkgs.lib.makeBinPath dotfilesCoreutils;
in {
  # https://devenv.sh/basics/
  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  # https://devenv.sh/packages/
  packages =
    dotfilesCoreutils
    ++ (with pkgs; [
      # AI
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.beads

      # Nix
      nix-unit
      namaka
      nixt

      # Rust toolchain
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer

      # System dependencies for Wayland compositor
      systemd
      libinput

      # Development tools
      direnv
      git
      gh
      jq
      nixpkgs-fmt
      pre-commit
      treefmt
      commitizen
      nodejs
      slumber
      lazysql

      # treefmt
      alejandra
      actionlint
      deadnix
      beautysh
      biome
      yamlfmt
      taplo
      rustfmt
      vulnix
    ]);

  # Prepend so `which cat` / `which wc` resolve to rust_* (Rust stdenv puts coreutils earlier in PATH).
  enterShell = ''
    export PATH="${dotfilesCoreutilsBin}:$PATH"
  '';

  # https://devenv.sh/languages/
  languages = {
    rust = {
      enable = true;
      channel = "stable";
      components = ["rustfmt" "clippy" "rust-analyzer"];
    };

    javascript = {
      enable = true;
      package = pkgs.nodejs;
      bun = {
        enable = true;
        package = pkgs.bun;
      };
    };
  };

  # git-hooks configuration disabled - pre-commit hooks work via .pre-commit-config.yaml
  # git-hooks = {
  #   hooks = {
  #     commitizen = {
  #       enable = true;
  #       stages = ["commit-msg"];
  #     };
  #     lint = {
  #       enable = true;
  #       stages = ["pre-commit"];
  #       name = "lint";
  #       description = "Lint the code";
  #       pass_filenames = true;
  #       entry = "treefmt --config-file treefmt.toml";
  #     };
  #   };
  # };
}
