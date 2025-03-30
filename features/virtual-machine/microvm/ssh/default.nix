{
  settings,
  pkgs,
  ...
}: {
  services = {
    openssh = {
      enable = true;
      ports = [22];
      openFirewall = true;
      settings = {
        PasswordAuthentication = true;
      };
    };
  };

  # Create a user with an empty password for testing
  users = {
    users = {
      "${settings.username}" = {
        isNormalUser = true;
        extraGroups = ["wheel"]; # Enable sudo
        initialPassword = "test";
      };
    };
  };

  # Allow sudo without password
  security = {
    sudo = {
      wheelNeedsPassword = false;
    };
  };
}
