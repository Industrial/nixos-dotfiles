args @ {...}: {
  android-tools = import ./android-tools/tests.nix args;
  bun = import ./bun/tests.nix args;
  deno = import ./deno/tests.nix args;
  docker-compose = import ./docker-compose/tests.nix args;
  edgedb = import ./edgedb/tests.nix args;
  git = import ./git/tests.nix args;
  gitkraken = import ./gitkraken/tests.nix args;
  gleam = import ./gleam/tests.nix args;
  glogg = import ./glogg/tests.nix args;
  insomnia = import ./insomnia/tests.nix args;
  local-ai = import ./local-ai/tests.nix args;
  meld = import ./meld/tests.nix args;
  neovim = import ./neovim/tests.nix args;
  nixd = import ./nixd/tests.nix args;
  nodejs = import ./nodejs/tests.nix args;
  ollama = import ./ollama/tests.nix args;
  sqlite = import ./sqlite/tests.nix args;
  vscode = import ./vscode/tests.nix args;
}
