{pkgs, ...}: {
  users = {
    users = {
      tom = {
        isNormalUser = true;
        home = "/home/tom";
        description = "Tom Wieland";
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "networkmanager"
          "plugdev"
        ];
        packages = [];
      };
    };
  };
}
