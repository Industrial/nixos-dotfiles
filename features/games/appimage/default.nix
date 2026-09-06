# AppImage support — run *.AppImage binaries directly.
# NixOS ships a stub-ld at /lib64/ld-linux-x86-64.so.2, so unpatched
# AppImages fail without appimage-run. binfmt registers the kernel
# handler so AppImages execute transparently (e.g. BlackthornLauncher).
{...}: {
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
