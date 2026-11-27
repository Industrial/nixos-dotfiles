# vwebbrowser (rust/tools/vwebbrowser): a WebKitGTK browser written in Voltaic on
# id_effect. 0.x and installed alongside librewolf, never instead of it: the desktop
# entry offers it for web links, but the xdg.mime defaults are left alone, so librewolf
# stays the default browser. Binary: vwebbrowser.
#
# Its search engine is /etc/xdg/vwebbrowser/config.toml's search_template. With
# features.network.searx on, that is the local SearXNG, on the port its service
# listens on (localhost, never a hostname); otherwise DuckDuckGo.
#
# Rollback: drop the host's `features.network.vwebbrowser.enable` line.
{
  config,
  pkgs,
  ...
}: let
  vwebbrowser = pkgs.callPackage ../../../rust/tools/vwebbrowser/default.nix {};

  desktopItem = pkgs.makeDesktopItem {
    name = "vwebbrowser";
    desktopName = "vwebbrowser";
    genericName = "Web Browser";
    comment = "Browse the web (Voltaic, WebKitGTK)";
    exec = "vwebbrowser %u";
    icon = "web-browser";
    categories = ["Network" "WebBrowser"];
    mimeTypes = ["text/html" "x-scheme-handler/http" "x-scheme-handler/https"];
    startupNotify = true;
  };

  # `or`: the switch exists only where lib/features.nix declares it (every host).
  searx = config.features.network.searx.enable or false;
  searxPort = config.services.searx.settings.server.port or 4001;

  settings = {
    search_template =
      if searx
      then "http://localhost:${toString searxPort}/search?q={query}"
      else "https://duckduckgo.com/?q={query}";
  };
in {
  environment.systemPackages = [vwebbrowser desktopItem];

  environment.etc."xdg/vwebbrowser/config.toml".source =
    (pkgs.formats.toml {}).generate "vwebbrowser-config.toml" settings;
}
