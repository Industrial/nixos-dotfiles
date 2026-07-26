{...}: {
  # SearXNG SQLite caches default to $TMPDIR; with PrivateTmp that lives on the
  # global /tmp tmpfs (2G). Point caches at CacheDirectory instead.
  systemd.services.searx.environment.TMPDIR = "/var/cache/searx";

  services = {
    searx = {
      enable = true;
      faviconsSettings = {
        favicons = {
          cfg_schema = 1;
          cache.db_url = "/var/cache/searx/faviconcache.db";
        };
      };
      settings = {
        server = {
          port = 4001;
          bind_address = "0.0.0.0";
          secret_key = "keyboardcat";
          limiter = false;
        };
        search = {
          formats = ["html" "json" "csv" "rss"];
        };
      };
    };
  };
}
