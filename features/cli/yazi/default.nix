# Yazi — async terminal file manager with image, video and archive preview.
{
  settings,
  pkgs,
  ...
}: let
  yaziToml = pkgs.writeTextFile {
    name = "yazi.toml";
    text = builtins.readFile ./yazi.toml;
  };
  keymapToml = pkgs.writeTextFile {
    name = "keymap.toml";
    text = builtins.readFile ./keymap.toml;
  };
in {
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

  imports = [../../../lib/vfiles.nix];

  vfiles.files = {
    "${settings.userdir}/.config/yazi/yazi.toml" = {
      source = yaziToml;
      user = settings.username;
    };
    "${settings.userdir}/.config/yazi/keymap.toml" = {
      source = keymapToml;
      user = settings.username;
    };
  };

  # The pre-vfiles script, kept for the rollback (features.nixos.vfiles off, lib/vfiles.nix).
  # Named for this feature: legacy names become activation script names, one namespace.
  vfiles.legacy.linkYaziConfig = {
    text = ''
      mkdir -p ${settings.userdir}/.config/yazi
      ln -sf ${yaziToml} ${settings.userdir}/.config/yazi/yazi.toml
      ln -sf ${keymapToml} ${settings.userdir}/.config/yazi/keymap.toml
    '';
  };
}
