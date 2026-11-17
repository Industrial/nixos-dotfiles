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
    # GameMode is off: on drakkar both of its privileged helpers are no-ops.
    # The governor is already `performance` (amd-pstate-epp) and
    # /proc/sys/kernel/split_lock_mitigate is already 0, so gamemoded spent
    # every 5s reaper tick asking pkexec for root to write values already set.
    # Worse, `nixos-rebuild switch` does not restart systemd *user* services,
    # so a long-lived gamemoded kept exec'ing the previous generation's
    # libexec/ paths. polkit matches pkexec requests by exact executable path,
    # so no com.feralinteractive.GameMode.* action matched and pkexec fell back
    # to org.freedesktop.policykit.exec (auth_admin) — an endless, unanswerable
    # password dialog.
    #
    # Re-enabling needs a polkit rule granting the GameMode actions to the
    # `gamemode` group; do not paper over it with a sudo/password grant.
    gamemode = {
      enable = false;
    };

    steam = {
      enable = true;
    };
  };
}
