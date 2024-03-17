let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.slock feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem "my-dwm" (builtins.attrNames feature.nixpkgs.overlays);
    expected = true;
  }
  {
    actual = builtins.fetchurl {
      url = "https://dwm.suckless.org/patches/autostart/dwm-autostart-20210120-cb3f58a.diff";
      hash = "sha256-mrHh4o9KBZDp2ReSeKodWkCz5ahCLuE6Al3NR2r2OJg=";
    };
    expected = pkgs.fetchpatch {
      url = "https://dwm.suckless.org/patches/autostart/dwm-autostart-20210120-cb3f58a.diff";
      hash = "sha256-mrHh4o9KBZDp2ReSeKodWkCz5ahCLuE6Al3NR2r2OJg=";
    };
  }
  # TODO: Test all patches.
]
