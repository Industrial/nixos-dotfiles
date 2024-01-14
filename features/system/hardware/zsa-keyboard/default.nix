{
  settings,
  pkgs,
  ...
}: {
  # https://configure.zsa.io/moonlander/layouts/qZnL4/latest/0

  hardware.keyboard.zsa.enable = true;

  environment.systemPackages = with pkgs; [
    wally-cli
  ];
}
