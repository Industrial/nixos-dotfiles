{pkgs, ...}: let
  # Override lutris to:
  # 1. Exclude /mnt from bwrap sandbox (avoids stale NFS automount failures)
  # 2. Fix Python/Pillow version mismatch in FHS environment
  # 3. Fix GIO module glib version mismatch in pressure-vessel container
  # 4. Make gamemode library available in FHS environment
  lutrisFixed = pkgs.lutris.override {
    extraPkgs = pkgs: [
      pkgs.vulkan-tools
    ];
    extraLibraries = pkgs: [
      pkgs.gamemode.lib
    ];
    buildFHSEnv = args:
      pkgs.buildFHSEnv (args
        // {
          # Clear PYTHONPATH and GIO_EXTRA_MODULES to prevent host packages
          # from leaking into the container (fixes glib version mismatch and
          # PIL version mismatch from hermes-agent/devenv)
          profile =
            (args.profile or "")
            + ''
              unset PYTHONPATH
              unset GIO_EXTRA_MODULES
            '';
          extraPreBwrapCmds =
            (args.extraPreBwrapCmds or "")
            + ''
              ignored+=(/mnt)
            '';
        });
  };
in {
  environment.systemPackages = with pkgs; [
    # (wineWow64Packages.waylandFull.override {
    #   wineRelease = "staging";
    #   gettextSupport = true;
    #   fontconfigSupport = true;
    #   alsaSupport = true;
    #   gtkSupport = true;
    #   openglSupport = true;
    #   tlsSupport = true;
    #   gstreamerSupport = true;
    #   openclSupport = true;
    #   udevSupport = true;
    #   vulkanSupport = true;
    #   mingwSupport = true;
    #   pulseaudioSupport = true;
    # })
    wineWow64Packages.fonts
    winetricks

    # bottles
    # heroic
    lutrisFixed
    protonup-qt
    vulkan-tools
  ];

  programs = {
    gamemode = {
      enable = true;
    };

    steam = {
      enable = true;
    };
  };
}
