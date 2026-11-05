# Navi is an interactive cheatsheet launcher for shell commands. Its binary is navi.
#
# The package was already here; the content is what makes it worth having. `cheats/` holds this
# repo's own .cheat files — the bin/ wrappers, the deploy-rs invocations, the gates, the
# `nix eval --raw .#nixosConfigurations.<host>…` idiom — rather than the generic Linux answers
# that tldr and cheat.sh already give. Nothing in them is invented: every entry was read out of
# the script or runbook it names in its own `;` provenance line.
#
# The sheets are linked in as `~/.local/share/navi/cheats/dotfiles` rather than named in
# config.yaml, for three reasons: `$XDG_DATA_HOME/navi/cheats` is navi's own
# `default_cheat_pathbuf()` so no configuration is needed to find them; navi's WalkDir follows
# symlinks so a store path works; and keeping the parent a real writable directory leaves room
# for `navi repo add` and for a sheet written by hand, which naming the store path in
# config.yaml would not.
{
  pkgs,
  settings,
  ...
}: let
  cheats = ./cheats;

  cheatsDir = "${settings.userdir}/.local/share/navi/cheats";
  configDir = "${settings.userdir}/.config/navi";

  configFile = pkgs.writeTextFile {
    name = "navi-config.yaml";
    text = builtins.readFile ./config.yaml;
  };
in {
  environment.systemPackages = with pkgs; [
    navi
  ];

  # Named for this feature rather than the generic linkFile that
  # features/window-manager/alacritty already claims: two features writing one
  # activation-script name is an evaluation conflict, not a merge.
  system.activationScripts.linkNaviCheats = {
    text = ''
      mkdir -p ${configDir}
      # navi writes no config of its own, but `navi info config-example > config.yaml` is the
      # documented way to start one. Keep a real file rather than clobber it, the same way
      # features/cli/atuin does.
      if [ -f ${configDir}/config.yaml ] && [ ! -L ${configDir}/config.yaml ]; then
        mv ${configDir}/config.yaml ${configDir}/config.yaml.backup
      fi
      ln -sfn ${configFile} ${configDir}/config.yaml
      chown -R ${settings.username}:users ${configDir}

      # The parent stays a real, user-owned directory on purpose: navi writes imported
      # repositories into it and only the `dotfiles` entry belongs to this feature.
      install -d -o ${settings.username} -g users -m 0755 ${cheatsDir}
      ln -sfn ${cheats} ${cheatsDir}/dotfiles
      # -h: chown the link itself. Following it would try to chown the store.
      chown -h ${settings.username}:users ${cheatsDir}/dotfiles
    '';
  };
}
