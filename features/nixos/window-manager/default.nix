{...}: {
  services = {
    xserver = {
      enable = true;
      dpi = 96;

      displayManager = {
        lightdm = {
          enable = true;
        };
      };
    };
  };
}
