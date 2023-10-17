{ pkgs, ... }: let
  startdwmContent = ''
    #!/usr/bin/env bash
    while true; do
      dwm 2> ~/.dwm.log
    done
  '';
  startdwm = pkgs.writeShellScriptBin "startdwm" startdwmContent;

  xinitrcContent = ''
    #!/bin/sh

    xrandr --output HDMI-A-0      --rotate normal --size 3840x2160 --rate 60.00 --primary &
    xrandr --output DisplayPort-1 --rotate left  --size 1920x1080 --rate 60.00 --left-of  HDMI-A-0 &
    xrandr --output DisplayPort-0 --rotate left  --size 1920x1080 --rate 60.00 --right-of HDMI-A-0 &

    $HOME/.bin/startdwm
  '';
  xinitrcFile = pkgs.writeShellScriptBin "$HOME/.xinitrc" xinitrcContent;
  xinitrcSymlink = pkgs.runCommand "symlink-xinitrc" {} ''
    mkdir -p $out
    ln -s ${xinitrcFile} $HOME/.xinitrc
  '';
in {
  services.xserver.windowManager.dwm.enable = true;

  nixpkgs.overlays = [
    (self: super: {
      dwm = super.dwm.overrideAttrs (oldAttrs: rec {
        configFile = self.writeText "config.def.h" (builtins.readFile ./config.h);

        postPatch = "${oldAttrs.postPatch}\n cp ${configFile} config.def.h";

        patches = [
          # # for local patch files, replace with the relative path to the patch file
          # ./path/to/local.patch
          # # for external patches
          # (pkgs.fetchpatch {
          #   # replace with the actual URL
          #   url = "https://dwm.suckless.org/patches/path/to/patch.diff";
          #   # replace hash with the value from `nix-prefetch-url "https://dwm.suckless.org/patches/path/to/patch.diff" | xargs nix hash to-sri --type sha256`
          #   # or just leave it blank, rebuild, and use the hash value from the error
          #   hash = "";
          # })
        ];
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    dmenu
    startdwm
    # xinitrcSymlink
  ];
}
