{
  settings,
  ...
}: {
  services = {
    tt-rss = {
      enable = true;
      selfUrlPath = "http://${settings.hostname}:9312";
    };
  };
}
