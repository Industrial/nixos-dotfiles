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
  # `nu` launch cannot shadow starship / aliases / Hávamál.
  system.activationScripts.linkNushellConfig = {
    text = ''
      mkdir -p /home/${settings.username}/.config/nushell
      for file in env.nu config.nu login.nu starship.nu havamal.nu; do
        target=/home/${settings.username}/.config/nushell/$file
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          mv "$target" "$target.backup"
        fi
        ln -sfn ${nushellDir}/$file "$target"
      done
      ln -sfn ${havamal}/share/fish/stanzas /home/${settings.username}/.config/nushell/havamal-stanzas
      chown -R ${settings.username}:users /home/${settings.username}/.config/nushell
    '';
  };
}
