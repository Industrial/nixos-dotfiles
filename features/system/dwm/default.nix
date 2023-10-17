{pkgs, ...}: {
  services.xserver.windowManager.dwm.enable = true;

  nixpkgs.overlays = [
    (self: super: {
      dwm = super.dwm.overrideAttrs (oldAttrs: rec {
        configFile = self.writeText "config.def.h" (builtins.readFile ./config.h);

        postPatch = "${oldAttrs.postPatch}\n cp ${configFile} config.def.h";

        patches = [
          # # for local patch files, replace with relative path to patch file
          # ./path/to/local.patch
          # # for external patches
          # (pkgs.fetchpatch {
          #   # replace with actual URL
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
  ];
}
