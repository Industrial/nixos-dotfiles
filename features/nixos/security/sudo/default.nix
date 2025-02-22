{...}: {
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
      execWheelOnly = true;
      # Disable the timeout on sudo. I'm sick of pressing my security keys.
      extraConfig = ''
        Defaults        timestamp_timeout=-1
      '';
    };
  };
}
