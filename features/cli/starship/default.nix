# Prompt.
#
# Starship runs unconfigured, which is the state this feature had before the declared
# 112-line `starship.toml` landed in terminal-frontier wave 4. Unconfigured means starship's
# own default `format`, i.e. `$all`: the directory, the git modules, and every language and
# toolchain module that detects its project -- the rust toolchain in a cargo tree, node in a
# package.json tree, and so on. That is the prompt that was asked for back, so the config
# file is gone rather than trimmed; there is no half-declared middle state to maintain.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    starship
  ];

  # The committed config used to be linked to `~/.config/starship.toml` from here. Dropping
  # the link is not enough on a host that already ran the old activation: the symlink stays,
  # and the store path it names stays readable until the next garbage collection, so starship
  # would keep rendering the declared prompt for days after the rebuild that removed it.
  #
  # Only a symlink is removed. A real file there is a hand-written config this feature has no
  # business deleting.
  imports = [../../../lib/vfiles.nix];

  # vfiles: `absent` removes a symlink there and reports a real file, exactly the prune.
  vfiles.files."${settings.userdir}/.config/starship.toml" = {
    mode = "absent";
    user = settings.username;
  };

  # The pre-vfiles script, kept for the rollback (features.nixos.vfiles off, lib/vfiles.nix).
  vfiles.legacy.pruneStarshipConfig = {
    text = ''
      target=${settings.userdir}/.config/starship.toml
      if [ -L "$target" ]; then
        rm -f "$target"
      fi
    '';
  };
}
