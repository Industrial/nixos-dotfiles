# DWM is a window manager.
{
  settings,
  config,
  pkgs,
  ...
}: {
  nixpkgs.overlays = [
    (self: super: {
      my-dwm = super.dwm.overrideAttrs (oldAttrs: rec {
        configFile = self.writeText "config.def.h" (builtins.readFile ./config.h);

        postPatch = "${oldAttrs.postPatch}\n cp ${configFile} config.def.h";

        patches = [
          # Autostart
          # This patch will make dwm run "~/.dwm/autostart_blocking.sh" and
          # "~/.dwm/autostart.sh &" before entering the handler loop. One or
          # both of these files can be ommited.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/autostart/dwm-autostart-20210120-cb3f58a.diff";
            hash = "sha256-mrHh4o9KBZDp2ReSeKodWkCz5ahCLuE6Al3NR2r2OJg=";
          })

          # Restart
          # DWM can now be restarted via MOD+CTRL+SHIFT+Q or by kill -HUP dwmpid
          # In addition, a signal handler was added so that dwm cleanly quits by
          # kill -TERM dwmpid.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/restartsig/dwm-restartsig-20180523-6.2.diff";
            hash = "sha256-OEvtUpbXZrAC/jlcjxigfCQIGYTnr9kFnXOUi7Xzc2k=";
          })

          # Active Monitor
          # By default you only see which monitor is active, when there is at
          # least one client on it. This patch shows the focused monitor, even
          # if there are no clients on it.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/activemonitor/dwm-activemonitor-20230825-e81f17d.diff";
            hash = "sha256-MEF/vSN3saZlvL4b26mp/7XyKG3Lp0FD0vTYPULuQXA=";
          })

          # Switch All Monitor Tags
          # Switches the selected tag of all monitors.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/switch_all_monitor_tags/dwm-switchallmonitortags-6.3.diff";
            hash = "sha256-nqP3l3dEBXfx1SjsO3pkj9HMJiD0AndYhDMTUtIOhx0=";
          })

          # Move Stack
          # `pushup` and `pushdown` provide a way to move clients inside the
          # clients list.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/push/dwm-push_no_master-6.4.diff";
            hash = "sha256-e/RKpPkBeI95Iwh+9xd4pssbZLdu41yh77ITJVd87qc=";
          })

          # Attach Aside
          # New clients attach at the bottom of the stack instead of the top.
          # Some users find this to be a less obtrusive attachment behavior,
          # since no existing clients are ever moved, only resized.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/attachaside/dwm-attachaside-6.4.diff";
            hash = "sha256-KUIO0oVxQs+RqRAXaEcHJWtG2b0OtWrgMWn0+m+1r78=";
          })

          # Layouts
          # TODO: Get this working / updated.
          # # CycleLayouts
          # (pkgs.fetchpatch {
          #   url = "https://dwm.suckless.org/patches/cyclelayouts/dwm-cyclelayouts-20180524-6.2.diff";
          #   hash = "sha256-iAoOIrK6knnJ3bdTGovjYiX0zjiyauxXY/6/5vhzB/k=";
          # })

          # CenteredMaster
          # `centeredmaster` and `centeredfloatingmaster` are two stack layouts
          # for dwm.
          # - `centeredmaster` centers the nmaster area on screen, using `mfact *
          #   monitor width & height`, with the stacked windows distributed to
          #   the left and right. It can be selected with [Alt]+[u].
          # - `centeredfloatingmaster` centers the nmaster area on screen, using
          #   `mfact * monitor width & height` over a horizontally tiled stack
          #   area, comparable to a scratchpad. It can be selected with
          #   `[Alt]+[o]`.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/centeredmaster/dwm-centeredmaster-6.1.diff";
            hash = "sha256-ueb1+Z0Kzym6ez389kl8lBtwhgrBTgQhSyQ2sJeOnbs=";
          })

          # TODO: Doesn't work.
          # # Systray
          # # A simple system tray implementation. Multi-monitor is also
          # # supported. The tray follows the selected monitor.
          # (pkgs.fetchpatch {
          #   url = "https://dwm.suckless.org/patches/systray/dwm-systray-6.4.diff";
          #   hash = "sha256-TXErH76w403T9tSJYu3tAJrQX3Y3lKSulKH0UdQLG/g=";
          # })

          # TODO: These don't work.
          # # Pertag
          # (pkgs.fetchpatch {
          #   url = "https://dwm.suckless.org/patches/pertag/dwm-pertag-20200914-61bb8b2.diff";
          #   hash = "sha256-wRZP/27V7xYOBnFAGxqeJFXdoDk4K1EQMA3bEoAXr/0=";
          # })
          # # Taglayouts
          # (pkgs.fetchpatch {
          #   url = "https://dwm.suckless.org/patches/taglayouts/dwm-taglayouts-6.4.diff";
          #   hash = "sha256-lXLb59Hx6C5kDhr8SeW14XYOO4UWv9vpEBPbiTCmGrI=";
          # })
        ];
      });
    })
  ];

  home.packages = with pkgs; [
    dmenu
    dunst
    my-dwm
    picom
  ];

  #home.file.".xinitrc".source = ./.xinitrc;
  home.file."dwm/autostart.sh".source = ./autostart.sh;
  home.file."dwm/autostart_blocking.sh".source = ./autostart_blocking.sh;
}
