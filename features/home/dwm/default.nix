# DWM is a window manager.
{pkgs, ...}: {
  nixpkgs.overlays = [
    (self: super: {
      dwm = super.dwm.overrideAttrs (oldAttrs: rec {
        configFile = self.writeText "config.def.h" (builtins.readFile ./config.h);

        postPatch = "${oldAttrs.postPatch}\n cp ${configFile} config.def.h";

        patches = [
          # DWM can now be restarted via MOD+CTRL+SHIFT+Q or by kill -HUP dwmpid
          # In addition, a signal handler was added so that dwm cleanly quits by
          # kill -TERM dwmpid.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/restartsig/dwm-restartsig-20180523-6.2.diff";
            hash = "sha256-OEvtUpbXZrAC/jlcjxigfCQIGYTnr9kFnXOUi7Xzc2k=";
          })

          # By default you only see which monitor is active, when there is at
          # least one client on it. This patch shows the focused monitor, even
          # if there are no clients on it.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/activemonitor/dwm-activemonitor-20230825-e81f17d.diff";
            hash = "sha256-MEF/vSN3saZlvL4b26mp/7XyKG3Lp0FD0vTYPULuQXA=";
          })

          # `pushup` and `pushdown` provide a way to move clients inside the
          # clients list.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/push/dwm-push_no_master-6.4.diff";
            hash = "sha256-e/RKpPkBeI95Iwh+9xd4pssbZLdu41yh77ITJVd87qc=";
          })

          # New clients attach at the bottom of the stack instead of the top.
          # Some users find this to be a less obtrusive attachment behavior,
          # since no existing clients are ever moved, only resized.
          (pkgs.fetchpatch {
            url = "https://dwm.suckless.org/patches/attachaside/dwm-attachaside-6.4.diff";
            hash = "sha256-KUIO0oVxQs+RqRAXaEcHJWtG2b0OtWrgMWn0+m+1r78=";
          })
        ];
      });
    })
  ];

  home.packages = with pkgs; [
    dmenu
    dwm
  ];

  home.file.".xinitrc".source = ./.xinitrc;
}
