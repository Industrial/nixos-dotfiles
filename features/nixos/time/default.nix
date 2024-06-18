{
  ...
}: {
  services = {
    ntpd-rs = {
      enable = true;
      metrics = {
        enable = true;
      };
    };
  };
}
