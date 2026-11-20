# Development Profile
# Development tools and programming environments
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.profiles.development.enable = lib.mkEnableOption "the development profile";

  config = lib.mkIf config.profiles.development.enable {
    features.finance.tws.enable = true;
    # features.finance.ib-gateway.enable = true;
    # features.programming.meld.enable = true;
    features.programming.neovim.enable = true;
    # features.programming.terraform.enable = true;
    # features.programming.vscode.enable = true;
    # features.programming.bun.enable = true;
    features.programming.cursor.enable = true;
    # Open-source VS Code build, configured to match cursor (same settings,
    # keybindings and extensions). See its header for the few differences.
    features.programming.vscodium.enable = true;
    features.programming.devenv.enable = true;
    features.programming.emerald.enable = true;
    # Lighter alternatives to cursor above, both on trial. They coexist with it
    # rather than replacing it: all three can be installed at once, and the one
    # that costs RAM is the one you actually open. Neither ships rust-analyzer —
    # see the header comments for the measurement that decided that.
    features.programming.helix.enable = true;
    features.programming.zed.enable = true;
    features.programming.voltaic.enable = true;
    features.programming.docker-compose.enable = true;
    features.programming.git.enable = true;
    features.programming.gitkraken.enable = true;
    features.programming.openidea.enable = true;
    # features.programming.glogg.enable = true;
    # features.programming.insomnia.enable = true;
    # features.programming.node.enable = true;
    # features.programming.pgadmin.enable = true;
    # features.programming.python.enable = true;
    # features.programming.zig.enable = true;

    # Which `node` is on PATH. openidea installs the default nodejs; zed (and paseo, via
    # profiles/ai.nix) install nodejs_22 for their own tooling. Both land in system-path,
    # and buildEnv resolves a file collision by list order — which is module order, i.e.
    # an accident of where a feature sits in the catalog. Decided here instead: the
    # default nodejs wins, as it did before features became switches.
    environment.systemPackages = [(lib.hiPrio pkgs.nodejs)];
  };
}
