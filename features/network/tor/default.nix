# Tor - The Onion Router
# Enables the Tor client daemon, which gives applications a local SOCKS proxy
# (127.0.0.1:9050). Tor Browser is intentionally not installed -- it was removed
# deliberately, so re-add `pkgs.tor-browser` only on purpose, not as a "the feature
# looks incomplete" fixup.
{...}: {
  services.tor = {
    enable = true;
    client.enable = true;
  };
}
