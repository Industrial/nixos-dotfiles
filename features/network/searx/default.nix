{...}: {
  services = {
    searx = {
      enable = true;
      settings = {
        server = {
          port = 4001;
          bind_address = "0.0.0.0";
          secret_key = "keyboardcat";
        };
      };
    };
  };
}
