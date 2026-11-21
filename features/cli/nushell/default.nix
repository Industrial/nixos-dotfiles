{
  settings,
  pkgs,
  ...
}: let
  # Mutable checkout so edits apply without a rebuild (same pattern as hyprland).
  nushellDir = "${settings.userdir}/.dotfiles/features/cli/nushell";
  havamal = pkgs.callPackage ../fish/havamal.nix {inherit settings pkgs;};
in {
  environment = {
    systemPackages = with pkgs; [
      nushell
    ];
    shells = with pkgs; [
      nushell
    ];
  };

  users.users."${settings.username}".shell = pkgs.nushell;

  # Link config on every activation so a fresh `~/.config/nushell` from first
  # `nu` launch cannot shadow aliases / Hávamál. The prompt and the NixOS session
  # variables are no longer linked from here: features/cli/shell-init generates
  # them into `$nu.data-dir/vendor/autoload`, which is why `login.nu` and
  # `starship.nu` are gone from this list and from the repo.
  imports = [../../../lib/vfiles.nix];

  vfiles.files = let
    configDir = "${settings.userdir}/.config/nushell";
    nu = file: {
      name = "${configDir}/${file}";
      value = {
        # Linked from the checkout, so an edit applies at the next `nu`; the committed copy
        # stands in while the checkout is missing.
        source = "${nushellDir}/${file}";
        fallback = ./. + "/${file}";
        user = settings.username;
      };
    };
    # Links earlier generations made, whose sources are gone: removed while still links.
    stale = file: {
      name = "${configDir}/${file}";
      value = {
        mode = "absent";
        user = settings.username;
      };
    };
  in
    builtins.listToAttrs (map nu ["env.nu" "config.nu" "havamal.nu"] ++ map stale ["login.nu" "starship.nu"])
    // {
      "${configDir}/havamal-stanzas" = {
        source = "${havamal}/share/fish/stanzas";
        user = settings.username;
      };
    };

  # The pre-vfiles script, kept for the rollback (features.nixos.vfiles off, lib/vfiles.nix).
  vfiles.legacy.linkNushellConfig = {
    text = ''
      mkdir -p /home/${settings.username}/.config/nushell
      for file in env.nu config.nu havamal.nu; do
        target=/home/${settings.username}/.config/nushell/$file
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          mv "$target" "$target.backup"
        fi
        ln -sfn ${nushellDir}/$file "$target"
      done
      # Earlier generations linked login.nu and starship.nu here; both sources are
      # gone, so the links are dangling. Remove them rather than leave litter in
      # the config directory.
      for stale in login.nu starship.nu; do
        target=/home/${settings.username}/.config/nushell/$stale
        if [ -L "$target" ]; then
          rm -f "$target"
        fi
      done
      ln -sfn ${havamal}/share/fish/stanzas /home/${settings.username}/.config/nushell/havamal-stanzas
      chown -R ${settings.username}:users /home/${settings.username}/.config/nushell
    '';
  };
}
