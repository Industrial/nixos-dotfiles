args @ {...}: {
  chromium = import ./chromium/tests.nix args;
  firefox = import ./firefox/tests.nix args;
  i2pd = import ./i2pd/tests.nix args;
  nginx = import ./nginx/tests.nix args;
  sshuttle = import ./sshuttle/tests.nix args;
  syncthing = import ./syncthing/tests.nix args;
  tor = import ./tor/tests.nix args;
  tor-browser = import ./tor-browser/tests.nix args;
}
