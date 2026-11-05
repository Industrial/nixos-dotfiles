# Yazi — async terminal file manager with image, video and archive preview.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # nixpkgs' yazi is a wrapper that already prefixes yazi's PATH with every
    # preview companion its own preset config spawns: file, jq, poppler-utils
    # (pdftoppm), _7zz, ffmpeg-headless (ffmpeg/ffprobe), fd, ripgrep, fzf,
    # zoxide, imagemagick (magick), chafa and resvg. None of those need adding
    # here; doing so would duplicate PATH entries for zero preview coverage.
    #
    # `exiftool` is the one binary yazi's shipped config names that the wrapper
    # does not provide: the preset `[opener] reveal` list ends with
    # `clear; exiftool %s1; ...` ("Show EXIF"), reachable with `O` on anything
    # whose `[open] rules` entry uses `reveal` -- i.e. nearly every file.
    # Without it that menu entry dies with `exiftool: command not found`.
    # `extraPackages` keeps it on yazi's PATH (and on the PATH of the shells
    # yazi spawns for openers) rather than on every login shell's.
    #
    # `settings` is deliberately not used: a non-empty `settings` makes the
    # wrapper --set YAZI_CONFIG_HOME to a store path, which would make the
    # ~/.config/yazi files linked below invisible.
    (yazi.override {extraPackages = [exiftool];})
  ];

  # Activation script names share one namespace across every feature, so this
  # one is named for its feature rather than the generic `linkFile`, which
  # features/window-manager/alacritty already defines.
  system.activationScripts.linkYaziConfig = {
    text = ''
      mkdir -p ${settings.userdir}/.config/yazi
      ln -sf ${pkgs.writeTextFile {
        name = "yazi.toml";
        text = builtins.readFile ./yazi.toml;
      }} ${settings.userdir}/.config/yazi/yazi.toml
      ln -sf ${pkgs.writeTextFile {
        name = "keymap.toml";
        text = builtins.readFile ./keymap.toml;
      }} ${settings.userdir}/.config/yazi/keymap.toml
    '';
  };
}
