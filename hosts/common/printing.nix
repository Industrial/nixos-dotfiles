{...}: {
  services = {
    printing = {
      enable = true;
      # TODO: Find correct driver.
      #drivers = with pkgs; [ cups-brother-ql-570 ];
    };
  };
}
