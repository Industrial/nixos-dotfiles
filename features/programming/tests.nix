args @ {...}: {
  android-tools = import ./android-tools/tests.nix args;
  bun = import ./bun/tests.nix args;
  deno = import ./deno/tests.nix args;
  docker-compose = import ./docker-compose/tests.nix args;
  edgedb = import ./edgedb/tests.nix args;
  git = import ./git/tests.nix args;
  gitkraken = import ./gitkraken/tests.nix args;
  glogg = import ./glogg/tests.nix args;
  insomnia = import ./insomnia/tests.nix args;
  meld = import ./meld/tests.nix args;
  neovim = import ./neovim/tests.nix args;
  nixd = import ./nixd/tests.nix args;
  nodejs = import ./nodejs/tests.nix args;
  python = import ./python/tests.nix args;
  vscode = import ./vscode/tests.nix args;
}
