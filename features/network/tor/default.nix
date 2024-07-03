{...}: {
  services = {
    tor = {
      enable = true;
      client = {
        enable = true;
        # port = 9051;
        # socksListenAddress = "127.0.0.1";
      };
      relay = {
        enable = false;
      };
    };
  };
}
